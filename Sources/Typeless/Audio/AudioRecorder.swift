import AVFoundation
import Foundation

protocol AudioRecording: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> RecordedAudioClip
    func recordingLevel(meteringEnabled: Bool) async -> Double
}

protocol StreamingAudioRecording: AudioRecording {
    func startRecording(onAudioChunk: @escaping @Sendable ([Float]) -> Void) async throws
}

extension AudioRecording {
    func recordingLevel(meteringEnabled: Bool) async -> Double { 0 }
}

protocol StreamingAudioCapturing: Sendable {
    func start() throws
    func stop() throws -> TimeInterval?
    var currentLevel: Double { get }
}

// Recording and metering share one executor so stopping cannot race a meter read.
actor AudioRecorder: StreamingAudioRecording {
    /// The process-wide temporary directory is shared with every other app, so recordings live in
    /// a folder of our own. That makes leftover-clip cleanup safe to do by wiping the directory.
    static let clipDirectory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("NoType", isDirectory: true)

    private var audioRecorder: AVAudioRecorder?
    private let recordingDirectory: URL
    private let makeStreamingCapture: @Sendable (URL, @escaping @Sendable ([Float]) -> Void) throws -> any StreamingAudioCapturing
    private var streamingCapture: (any StreamingAudioCapturing)?
    private var currentClipURL: URL?
    private var isRecording = false

    init(
        recordingDirectory: URL = AudioRecorder.clipDirectory,
        makeStreamingCapture: @escaping @Sendable (URL, @escaping @Sendable ([Float]) -> Void) throws -> any StreamingAudioCapturing = {
            try StreamingAudioCapture(outputURL: $0, onAudioChunk: $1)
        }
    ) {
        self.recordingDirectory = recordingDirectory
        self.makeStreamingCapture = makeStreamingCapture
    }

    func recordingLevel(meteringEnabled: Bool) -> Double {
        if let streamingCapture {
            return meteringEnabled ? streamingCapture.currentLevel : 0
        }

        guard let audioRecorder, isRecording else { return 0 }
        if audioRecorder.isMeteringEnabled != meteringEnabled {
            audioRecorder.isMeteringEnabled = meteringEnabled
        }
        guard meteringEnabled else { return 0 }
        // Apple requires refreshing the meters before reading dBFS.
        // https://developer.apple.com/documentation/avfaudio/avaudiorecorder/updatemeters()
        audioRecorder.updateMeters()
        return Self.normalizedLevel(decibels: audioRecorder.averagePower(forChannel: 0))
    }

    static func normalizedLevel(decibels: Float) -> Double {
        guard decibels.isFinite else { return 0 }
        // Gate background hiss and expand normal speech into the small waveform's range.
        return pow(min(1, max(0, (Double(decibels) + 55) / 55)), 1.5)
    }

    /// Clears clips a previous run failed to delete, e.g. after a crash during transcription.
    static func removeOrphanedClips() {
        let fileManager = FileManager.default
        guard let leftovers = try? fileManager.contentsOfDirectory(
            at: clipDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        let clips = leftovers.filter { $0.pathExtension.lowercased() == "wav" }
        guard !clips.isEmpty else { return }

        for clip in clips {
            try? fileManager.removeItem(at: clip)
        }
        AppLogger.log("AudioRecorder: removed \(clips.count) orphaned clip(s) from \(clipDirectory.path)")
    }

    func startRecording() async throws {
        guard !isRecording else {
            AppLogger.log("AudioRecorder.startRecording: already recording")
            throw AudioSessionError.alreadyRecording
        }

        try FileManager.default.createDirectory(
            at: recordingDirectory,
            withIntermediateDirectories: true
        )
        let tempFileURL = recordingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        currentClipURL = tempFileURL
        let recorder = try AVAudioRecorder(url: tempFileURL, settings: settings)
        recorder.prepareToRecord()
        recorder.isMeteringEnabled = false

        guard recorder.record() else {
            AppLogger.log("AudioRecorder.startRecording: recorder.record() returned false")
            throw AudioSessionError.failedToPrepareRecorder
        }

        audioRecorder = recorder
        isRecording = true
        AppLogger.log("AudioRecorder.startRecording: recording to \(tempFileURL.path)")
    }

    func startRecording(onAudioChunk: @escaping @Sendable ([Float]) -> Void) async throws {
        guard !isRecording else {
            AppLogger.log("AudioRecorder.startRecording(streaming): already recording")
            throw AudioSessionError.alreadyRecording
        }

        try FileManager.default.createDirectory(
            at: recordingDirectory,
            withIntermediateDirectories: true
        )
        let tempFileURL = recordingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        do {
            let capture = try makeStreamingCapture(tempFileURL, onAudioChunk)
            try capture.start()
            streamingCapture = capture
            currentClipURL = tempFileURL
            isRecording = true
            AppLogger.log("AudioRecorder.startRecording(streaming): recording to \(tempFileURL.path)")
        } catch {
            try? FileManager.default.removeItem(at: tempFileURL)
            throw error
        }
    }

    func stopRecording() async throws -> RecordedAudioClip {
        guard let currentClipURL else {
            AppLogger.log("AudioRecorder.stopRecording: missing output file")
            throw AudioSessionError.missingOutputFile
        }

        let duration: TimeInterval?
        if let streamingCapture {
            do {
                duration = try streamingCapture.stop()
            } catch {
                self.streamingCapture = nil
                self.currentClipURL = nil
                audioRecorder = nil
                isRecording = false
                // stopRecording throws before the coordinator can receive and delete a clip.
                try? FileManager.default.removeItem(at: currentClipURL)
                throw error
            }
            self.streamingCapture = nil
        } else {
            // currentTime resets once the recorder stops, so read it while it is still running.
            duration = audioRecorder?.currentTime
            audioRecorder?.stop()
        }
        audioRecorder = nil
        self.currentClipURL = nil
        isRecording = false
        AppLogger.log(
            "AudioRecorder.stopRecording: finished recording to \(currentClipURL.path), " +
            "duration=\(duration.map { String(format: "%.2fs", $0) } ?? "unknown")"
        )

        return RecordedAudioClip(fileURL: currentClipURL, duration: duration)
    }
}

/// AVAudioEngine tap used only by the streaming engine.
///
/// The existing AVAudioRecorder path remains in place for the offline engines. This tee writes the
/// same 16 kHz mono WAV shape while forwarding float PCM chunks to R2T2, so a streaming session can
/// still be deleted and diagnosed through the same RecordedAudioClip lifecycle.
private final class StreamingAudioCapture: StreamingAudioCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let outputFile: AVAudioFile
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let onAudioChunk: @Sendable ([Float]) -> Void
    private let lock = NSLock()
    private var stopped = false
    private var frameCount: AVAudioFramePosition = 0
    private var latestLevel = 0.0
    private var writeError: Error?

    init(
        outputURL: URL,
        onAudioChunk: @escaping @Sendable ([Float]) -> Void
    ) throws {
        inputNode = engine.inputNode
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(AudioSamplesLoader.sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw AudioSessionError.invalidInputFormat
        }
        self.outputFormat = outputFormat
        self.outputFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0,
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioSessionError.invalidInputFormat
        }
        self.converter = converter
        self.onAudioChunk = onAudioChunk
    }

    func start() throws {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize = AVAudioFrameCount(max(256, Int(Double(inputFormat.sampleRate) * 0.02)))
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() throws -> TimeInterval? {
        lock.lock()
        guard !stopped else {
            let duration = durationLocked
            let error = writeError
            lock.unlock()
            if let error { throw AudioSessionError.captureFailed(error.localizedDescription) }
            return duration
        }
        stopped = true
        let duration = durationLocked
        let error = writeError
        lock.unlock()

        engine.stop()
        inputNode.removeTap(onBus: 0)
        if let error { throw AudioSessionError.captureFailed(error.localizedDescription) }
        return duration
    }

    var currentLevel: Double {
        lock.lock()
        defer { lock.unlock() }
        return latestLevel
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        guard !stopped, writeError == nil else {
            lock.unlock()
            return
        }

        let outputCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate) + 1
        )
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: max(outputCapacity, 1)
        ) else {
            writeError = AudioSessionError.invalidInputFormat
            lock.unlock()
            return
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            guard !consumed else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, conversionError == nil else {
            writeError = conversionError ?? AudioSessionError.invalidInputFormat
            lock.unlock()
            return
        }
        // A converter may buffer input without producing frames yet; this is not a failure.
        guard converted.frameLength > 0 else { lock.unlock(); return }
        guard let channelData = converted.floatChannelData else {
            writeError = conversionError ?? AudioSessionError.invalidInputFormat
            lock.unlock()
            return
        }

        do {
            try outputFile.write(from: converted)
        } catch {
            writeError = error
            lock.unlock()
            return
        }

        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(converted.frameLength)
        ))
        frameCount += AVAudioFramePosition(converted.frameLength)
        let meanSquare = samples.reduce(Float.zero) { $0 + ($1 * $1) } / Float(samples.count)
        latestLevel = AudioRecorder.normalizedLevel(decibels: 20 * log10(max(meanSquare.squareRoot(), 0.00001)))
        // Publish under the same lock as stop(): once stop returns, every accepted chunk is queued.
        onAudioChunk(samples)
        lock.unlock()
    }

    private var durationLocked: TimeInterval? {
        guard frameCount > 0 else { return nil }
        return Double(frameCount) / outputFormat.sampleRate
    }
}
