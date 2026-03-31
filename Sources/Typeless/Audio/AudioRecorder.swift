import AVFoundation
import Foundation

protocol AudioRecording: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> RecordedAudioClip
}

final class AudioRecorder: NSObject, AudioRecording, @unchecked Sendable {
    private var audioRecorder: AVAudioRecorder?
    private var currentClipURL: URL?
    private var isRecording = false

    func startRecording() async throws {
        guard !isRecording else {
            AppLogger.log("AudioRecorder.startRecording: already recording")
            throw AudioSessionError.alreadyRecording
        }

        let tempFileURL = FileManager.default.temporaryDirectory
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

        audioRecorder?.stop()
        audioRecorder = nil
        self.currentClipURL = nil
        isRecording = false
        AppLogger.log("AudioRecorder.stopRecording: finished recording to \(currentClipURL.path)")

        return RecordedAudioClip(fileURL: currentClipURL)
    }
}
