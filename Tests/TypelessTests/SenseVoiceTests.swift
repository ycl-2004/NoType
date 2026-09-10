import Foundation
import Testing
@testable import Typeless

struct SenseVoicePathTests {
    @Test
    func modelLivesInTheSharedHuggingFaceDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedBase = "\(home)/Documents/huggingface/models/k2-fsa"

        #expect(SenseVoicePaths.sharedModelBaseFolder.path == expectedBase)
        #expect(SenseVoicePaths.modelFolder.path.hasPrefix(expectedBase))
        #expect(SenseVoicePaths.modelURL.lastPathComponent == SenseVoicePaths.modelFileName)
        #expect(SenseVoicePaths.tokensURL.lastPathComponent == SenseVoicePaths.tokensFileName)
    }

    @Test
    func modelDownloadUsesTheOfficialSherpaArchive() {
        #expect(SenseVoicePaths.modelDownloadURL.host == "github.com")
        #expect(SenseVoicePaths.modelDownloadURL.path.contains("k2-fsa/sherpa-onnx/releases/download/asr-models"))
        #expect(SenseVoicePaths.modelDownloadURL.lastPathComponent == SenseVoicePaths.archiveFileName)
    }

    @Test
    func modelManagerTargetsOnlyNoTypeModelFolders() {
        let qwenPaths = LocalModelManager.managedPaths(for: .qwen3ASR)
        let senseVoicePaths = LocalModelManager.managedPaths(for: .senseVoice)

        #expect(senseVoicePaths == [SenseVoicePaths.modelFolder])
        #expect(qwenPaths == [Qwen3ASRPaths.modelFolder])
        #expect((qwenPaths + senseVoicePaths).allSatisfy { $0.path.hasPrefix("/") })
        #expect((qwenPaths + senseVoicePaths).allSatisfy { $0.path.contains("/huggingface") })
        #expect((qwenPaths + senseVoicePaths).allSatisfy { $0.path.contains(".app/Contents") == false })
    }
}

@MainActor
struct SenseVoiceEngineTests {
    @Test
    func mapsRecognitionModesToSenseVoiceLanguageHints() {
        #expect(SenseVoiceTranscriptionEngine.modelLanguageCode(for: .mixed) == "auto")
        #expect(SenseVoiceTranscriptionEngine.modelLanguageCode(for: .chinese) == "zh")
        #expect(SenseVoiceTranscriptionEngine.modelLanguageCode(for: .english) == "en")
    }
}
