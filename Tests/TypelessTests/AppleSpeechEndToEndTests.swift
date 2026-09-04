import Foundation
import Speech
import Testing
@testable import Typeless

/// Exercises the real engine against a real recording, which unit tests over pure functions cannot
/// do: asset preparation, permission handling, and multi-segment joining only exist on this path.
///
/// Point `NOTYPE_E2E_CLIP` at a WAV file to run it — the suite skips itself otherwise, so a clean
/// checkout without on-device assets or speech permission still passes.
///
///     NOTYPE_E2E_CLIP=/path/to/clip.wav swift test
///
/// The clip is transcribed as Chinese because that is a route the router actually sends to this
/// engine — `Auto` is deliberately handled by Whisper instead.
struct AppleSpeechEndToEndTests {
    @Test
    func transcribesARealClipThroughTheProductionPath() async throws {
        guard #available(macOS 26.0, *) else { return }
        guard let path = ProcessInfo.processInfo.environment["NOTYPE_E2E_CLIP"] else { return }
        // Requesting Speech Recognition without a usage description terminates the process, and
        // the test runner bundle declares none, so only an already-granted permission is usable.
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            Issue.record("NOTYPE_E2E_CLIP is set but Speech Recognition is not authorized for the test runner")
            return
        }

        let clipURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: clipURL.path) else {
            Issue.record("NOTYPE_E2E_CLIP points at a missing file: \(path)")
            return
        }

        let engine = await AppleSpeechTranscriptionEngine()
        let result = try await engine.transcribe(
            RecordedAudioClip(fileURL: clipURL),
            language: .chinese,
            chineseScriptPreference: .simplified
        )

        print("E2E transcript: \(result.text)")
        #expect(result.text.isEmpty == false)
    }
}
