import Foundation
import Testing
@testable import Typeless

struct AudioRecorderFailureTests {
    @Test
    func failedStreamingCaptureDeletesPartialFileAndCanStartAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = AudioRecorder(recordingDirectory: directory, makeStreamingCapture: { url, _ in
            try Data("partial audio".utf8).write(to: url)
            return FailingStreamingCapture()
        })
        for _ in 0..<2 {
            try await recorder.startRecording(onAudioChunk: { _ in })
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
            await #expect(throws: AudioSessionError.captureFailed("disk full")) {
                try await recorder.stopRecording()
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }
}

private struct FailingStreamingCapture: StreamingAudioCapturing {
    var currentLevel: Double { 0 }
    func start() throws {}
    func stop() throws -> TimeInterval? { throw AudioSessionError.captureFailed("disk full") }
}
