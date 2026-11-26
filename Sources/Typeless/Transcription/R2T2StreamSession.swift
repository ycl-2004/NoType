import Foundation

enum R2T2DecodeError: Error {
    case limitReached
}

/// Each committed segment is decoded once. Over-limit segments are retried in smaller pieces;
/// a failed retry fails the whole dictation instead of inserting a silently incomplete result.
enum R2T2SegmentDecoder {
    static let maximumSamples = Int(AudioChunker.maximumChunkDuration) * R2T2Paths.sampleRate

    static func ranges(for samples: [Float]) -> [Range<Int>] {
        let vad = AudioEnergyVAD()
        return AudioChunker.chunkRanges(
            voiceActivity: vad.voiceActivity(in: samples), totalSamples: samples.count,
            samplesPerFrame: vad.frameLengthSamples, sampleRate: R2T2Paths.sampleRate
        )
    }

    static func transcribe(
        _ samples: [Float], runtime: any R2T2Runtime, language: DictationRecognitionLanguage
    ) async throws -> String {
        var parts: [String] = []
        for range in ranges(for: samples) {
            parts.append(try await decode(Array(samples[range]), runtime: runtime, language: language))
        }
        return join(parts)
    }

    private static func decode(
        _ samples: [Float], runtime: any R2T2Runtime, language: DictationRecognitionLanguage
    ) async throws -> String {
        try Task.checkCancellation()
        do {
            return R2T2TranscriptionEngine.normalizeRawText(
                try await runtime.transcribe(samples: samples, language: language)
            )
        } catch R2T2DecodeError.limitReached {
            guard samples.count > R2T2Paths.sampleRate else {
                throw TranscriptionError.failed("R2T2 reached its decoding limit. No incomplete text was inserted. Please retry a shorter recording.")
            }
            let middle = samples.count / 2
            let left = try await decode(Array(samples[..<middle]), runtime: runtime, language: language)
            let right = try await decode(Array(samples[middle...]), runtime: runtime, language: language)
            return join([left, right])
        }
    }

    static func join(_ parts: [String]) -> String {
        TranscriptSegmentJoiner.join(parts)
    }
}

/// A single consumer preserves microphone order and drains every accepted chunk before finalizing.
/// No per-callback Tasks can overtake the stop event.
/// https://developer.apple.com/documentation/swift/asyncstream/continuation
final class R2T2AudioStream: Sendable {
    let id: UUID
    let session: R2T2StreamSession
    private let continuation: AsyncStream<[Float]>.Continuation
    private let consumer: Task<Void, Never>

    init(id: UUID = UUID(), session: R2T2StreamSession) {
        self.id = id
        self.session = session
        let (stream, continuation) = AsyncStream<[Float]>.makeStream()
        self.continuation = continuation
        consumer = Task {
            for await samples in stream {
                await session.append(samples)
            }
        }
    }

    func append(_ samples: [Float]) { continuation.yield(samples) }

    func finish() async throws -> String {
        continuation.finish()
        await consumer.value
        return try await session.finish()
    }

    func cancel() {
        continuation.finish()
        consumer.cancel()
        Task { await session.cancel() }
    }
}

actor R2T2StreamSession {
    let language: DictationRecognitionLanguage
    let chineseScriptPreference: ChineseScriptPreference
    private let runtime: any R2T2Runtime
    private let previewsEnabled: Bool
    private let onPreview: @Sendable (String) -> Void
    private var samples: [Float] = []
    private var completed: [String] = []
    private var cachedPreview: (count: Int, text: String)?
    private var lastPreviewCount = 0
    private var processingTask: Task<Void, Never>?
    /// What the in-flight decode covers, so stop can tell whether its result is still useful.
    private var processing: (count: Int, commitsSegment: Bool)?
    private var isFinishing = false
    private var isCancelled = false
    private var partialFailed = false

    init(
        runtime: any R2T2Runtime,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference,
        previewsEnabled: Bool = true,
        onPreview: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.language = language
        self.chineseScriptPreference = chineseScriptPreference
        self.previewsEnabled = previewsEnabled
        self.onPreview = onPreview
    }

    func append(_ newSamples: [Float]) {
        guard !isCancelled, !isFinishing, !newSamples.isEmpty else { return }
        samples.append(contentsOf: newSamples)
        scheduleIfNeeded()
    }

    func finish() async throws -> String {
        guard !isCancelled else { throw CancellationError() }
        isFinishing = true
        if let processingTask {
            // Audio keeps arriving while a preview decodes, so a preview started before stop
            // almost never covers the final sample count and would be decoded only to be thrown
            // away. Cancel it so the final decode starts now. A segment commit is always kept.
            if let processing, processing.commitsSegment == false, processing.count != samples.count {
                processingTask.cancel()
            }
            await processingTask.value
        }
        guard !isCancelled else { throw CancellationError() }
        defer {
            samples.removeAll(keepingCapacity: false)
            cachedPreview = nil
            completed.removeAll()
        }
        let tail: String
        if let cachedPreview, cachedPreview.count == samples.count {
            tail = cachedPreview.text
        } else {
            tail = try await R2T2SegmentDecoder.transcribe(samples, runtime: runtime, language: language)
        }
        guard !isCancelled else { throw CancellationError() }
        return R2T2SegmentDecoder.join(completed + [tail])
    }

    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        samples.removeAll(keepingCapacity: false)
        cachedPreview = nil
        completed.removeAll()
    }

    private func scheduleIfNeeded() {
        guard !isFinishing, !isCancelled, !partialFailed, processingTask == nil else { return }
        let maximum = R2T2SegmentDecoder.maximumSamples
        let commitsSegment = samples.count > maximum
        let count: Int
        if commitsSegment {
            // Inspect at most one window, even if inference has fallen behind the microphone.
            let window = Array(samples.prefix(maximum + 1))
            count = R2T2SegmentDecoder.ranges(for: window)[0].count
        } else {
            // Preserve the first 320 ms preview, then back off as the current segment grows.
            let interval = lastPreviewCount == 0
                ? R2T2Paths.sampleRate * R2T2Paths.chunkDurationMilliseconds / 1_000
                : max(2 * R2T2Paths.sampleRate, lastPreviewCount / 2)
            guard previewsEnabled, samples.count - lastPreviewCount >= interval else { return }
            count = samples.count
            lastPreviewCount = count
        }
        let snapshot = Array(samples.prefix(count))
        processing = (count, commitsSegment)
        processingTask = Task { [runtime, language] in
            do {
                let text = try await R2T2SegmentDecoder.transcribe(snapshot, runtime: runtime, language: language)
                self.decoded(text, count: count, commitsSegment: commitsSegment)
            } catch {
                self.processingTask = nil
                self.processing = nil
                if error is CancellationError, self.isFinishing || self.isCancelled { return }
                self.partialFailed = true
                if !self.isCancelled {
                    AppLogger.log("R2T2: preview failed; finalization will retry the pending audio: \(error)")
                }
            }
        }
    }

    private func decoded(_ text: String, count: Int, commitsSegment: Bool) {
        processingTask = nil
        processing = nil
        guard !isCancelled else { return }
        if commitsSegment {
            completed.append(text)
            samples.removeFirst(count)
            cachedPreview = nil
            lastPreviewCount = 0
        } else {
            cachedPreview = (count, text)
        }
        if !isFinishing {
            onPreview(R2T2SegmentDecoder.join(completed + (commitsSegment ? [] : [text])))
            scheduleIfNeeded()
        }
    }
}
