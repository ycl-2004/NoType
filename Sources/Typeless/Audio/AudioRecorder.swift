import AVFoundation
import Foundation

protocol AudioRecording: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> RecordedAudioClip
}

final class AudioRecorder: NSObject, AudioRecording, @unchecked Sendable {
    /// The process-wide temporary directory is shared with every other app, so recordings live in
    /// a folder of our own. That makes leftover-clip cleanup safe to do by wiping the directory.
    static let clipDirectory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("NoType", isDirectory: true)

    private var audioRecorder: AVAudioRecorder?
    private var currentClipURL: URL?
    private var isRecording = false

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
            at: Self.clipDirectory,
            withIntermediateDirectories: true
        )
        let tempFileURL = Self.clipDirectory
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

    func stopRecording() async throws -> RecordedAudioClip {
        guard let currentClipURL else {
            AppLogger.log("AudioRecorder.stopRecording: missing output file")
            throw AudioSessionError.missingOutputFile
        }

        // currentTime resets once the recorder stops, so read it while it is still running.
        let duration = audioRecorder?.currentTime
        audioRecorder?.stop()
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
