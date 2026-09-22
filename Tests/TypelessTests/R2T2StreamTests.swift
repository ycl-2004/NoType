import Foundation
import Testing
@testable import Typeless

struct R2T2StreamTests {
    @Test
    func stopDrainsEveryAudioChunkInOrderWithoutPreviewWork() async throws {
        let runtime = SampleRecordingRuntime()
        let session = R2T2StreamSession(runtime: runtime, language: .mixed,
                                       chineseScriptPreference: .followModel, previewsEnabled: false)
        let stream = R2T2AudioStream(session: session)
        let chunks = (0..<1_000).map { [Float($0)] }
        for chunk in chunks { stream.append(chunk) }
        let result = try await stream.finish()
        let seen = await runtime.seen
        #expect(seen.flatMap { $0 } == chunks.flatMap { $0 })
        #expect(seen.count == 1)
        #expect(result == "1000")
    }

    @Test
    func fiveMinuteRecordingIsBoundedAndEverySampleIsDecodedOnce() async throws {
        let runtime = SampleRecordingRuntime()
        let session = R2T2StreamSession(runtime: runtime, language: .mixed,
                                       chineseScriptPreference: .followModel, previewsEnabled: false)
        let stream = R2T2AudioStream(session: session)
        let second = [Float](repeating: 0.1, count: R2T2Paths.sampleRate)
        for _ in 0..<300 { stream.append(second) }
        _ = try await stream.finish()
        let seen = await runtime.seen
        #expect(seen.count > 1)
        #expect(seen.allSatisfy { $0.count <= R2T2SegmentDecoder.maximumSamples })
        #expect(seen.reduce(0) { $0 + $1.count } == 300 * R2T2Paths.sampleRate)
    }

    @Test
    func exactPreviewIsReusedAtStop() async throws {
        let runtime = SampleRecordingRuntime()
        let preview = StreamTestSignal()
        let session = R2T2StreamSession(runtime: runtime, language: .mixed,
                                       chineseScriptPreference: .followModel,
                                       onPreview: { _ in Task { await preview.signal() } })
        await session.append([Float](repeating: 0.1, count: 16_000))
        await preview.wait()
        let result = try await session.finish()
        #expect(result == "16000")
        #expect(await runtime.seen.count == 1)
    }

    @Test
    func previewBackoffAvoidsDecodingEvery320Milliseconds() async throws {
        let runtime = SampleRecordingRuntime()
        let preview = StreamTestSignal()
        let session = R2T2StreamSession(runtime: runtime, language: .mixed,
                                       chineseScriptPreference: .followModel,
                                       onPreview: { _ in Task { await preview.signal() } })
        await session.append([Float](repeating: 0.1, count: 5_120))
        await preview.wait()
        for _ in 0..<5 { await session.append([Float](repeating: 0.1, count: 5_120)) }
        _ = try await session.finish()
        #expect(await runtime.seen.count == 2) // first preview, then final tail
    }

    @Test
    func decoderRetriesLimitsWithoutLosingEitherHalf() async throws {
        let runtime = SampleRecordingRuntime(limit: 16_000)
        let samples = (0..<32_000).map { Float($0) }
        let text = try await R2T2SegmentDecoder.transcribe(samples, runtime: runtime, language: .english)
        #expect(text == "16000 16000")
        let seen = await runtime.seen
        #expect(seen.filter { $0.count <= 16_000 }.flatMap { $0 } == samples)
    }

    @Test
    func irreducibleLimitFailsInsteadOfReturningPartialText() async throws {
        let runtime = SampleRecordingRuntime(limit: 0)
        await #expect(throws: TranscriptionError.self) {
            try await R2T2SegmentDecoder.transcribe([Float](repeating: 0.1, count: 16_000),
                                                  runtime: runtime, language: .mixed)
        }
    }

    @Test
    func cancelledSessionCannotReturnText() async throws {
        let runtime = SampleRecordingRuntime()
        let session = R2T2StreamSession(runtime: runtime, language: .mixed,
                                       chineseScriptPreference: .followModel, previewsEnabled: false)
        await session.append([0.1])
        await session.cancel()
        await #expect(throws: CancellationError.self) { try await session.finish() }
        #expect(await runtime.seen.isEmpty)
    }
}

private actor SampleRecordingRuntime: R2T2Runtime {
    private(set) var seen: [[Float]] = []
    let limit: Int?
    init(limit: Int? = nil) { self.limit = limit }
    func transcribe(samples: [Float], language: DictationRecognitionLanguage) async throws -> String {
        seen.append(samples)
        if let limit, samples.count > limit { throw R2T2DecodeError.limitReached }
        return String(samples.count)
    }
}

private actor StreamTestSignal {
    private var fired = false
    private var waiter: CheckedContinuation<Void, Never>?
    func signal() { fired = true; waiter?.resume(); waiter = nil }
    func wait() async {
        if fired { return }
        await withCheckedContinuation { waiter = $0 }
    }
}
