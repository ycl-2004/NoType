import Foundation
import Testing
@testable import Typeless

struct Qwen3ASREndToEndTests {
    /// Opt in with NOTYPE_QWEN_E2E_CLIP pointing to a 16 kHz mono WAV.
    /// Requires the Qwen3 model to be installed in the normal shared model directory.
    @Test
    func transcribesARealClipThroughTheProductionPath() async throws {
        guard let path = ProcessInfo.processInfo.environment["NOTYPE_QWEN_E2E_CLIP"] else { return }
        let engine = await Qwen3ASRTranscriptionEngine()
        let result = try await engine.transcribe(
            RecordedAudioClip(fileURL: URL(fileURLWithPath: path)),
            language: .mixed,
            chineseScriptPreference: .simplified
        )
        print("Qwen3 E2E transcript: \(result.text)")
        #expect(!result.text.isEmpty)
        #expect(!result.rawText.isEmpty)
    }
}
