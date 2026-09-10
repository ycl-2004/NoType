import Foundation
import Testing
@testable import Typeless

struct Qwen3ASRPathsTests {
    @Test
    func modelLivesInTheSharedHuggingFaceDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedBase = "\(home)/Documents/huggingface/models/k2-fsa"

        #expect(Qwen3ASRPaths.sharedModelBaseFolder.path == expectedBase)
        #expect(Qwen3ASRPaths.modelFolder.path.hasPrefix(expectedBase))
        #expect(Qwen3ASRPaths.modelFolder.lastPathComponent == Qwen3ASRPaths.modelPackageName)
    }

    @Test
    func modelDownloadUsesTheOfficialSherpaArchive() {
        #expect(Qwen3ASRPaths.modelDownloadURL.host == "github.com")
        #expect(Qwen3ASRPaths.modelDownloadURL.path.contains("k2-fsa/sherpa-onnx/releases/download/asr-models"))
        #expect(Qwen3ASRPaths.modelDownloadURL.lastPathComponent == Qwen3ASRPaths.archiveFileName)
    }

    @Test
    func modelValidationNamesTheQwen3ASRDirectoryWhenItIsMissing() {
        guard Qwen3ASRPaths.modelFolderExists == false else { return }

        let error = Qwen3ASRPaths.validationError()
        #expect(error?.contains("Qwen3-ASR") == true)
        #expect(error?.contains(Qwen3ASRPaths.modelPackageName) == true)
    }
}
