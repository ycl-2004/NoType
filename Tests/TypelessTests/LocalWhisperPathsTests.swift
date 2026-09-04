import Foundation
import Testing
@testable import Typeless

struct LocalWhisperPathsTests {
    /// The shared location must win over a copy inside the app bundle. Core ML caches its model
    /// specialization per model path, so a path that moves into a replaced bundle discards the
    /// cache: measured at 4m13s to reload after one rebuild, against 4s when the path held still.
    @Test
    func resolvesToTheSharedLocationWhenItHasTheModel() {
        let shared = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml")
            .appendingPathComponent("openai_whisper-large-v3-v20240930_turbo")

        guard FileManager.default.fileExists(atPath: shared.path) else { return }

        #expect(LocalWhisperPaths.modelFolder == shared.path)
        #expect(LocalWhisperPaths.modelFolder.hasPrefix("/Applications") == false)
    }

    /// The path is derived from the current user's home directory, not a hardcoded username, so a
    /// second account on the same Mac resolves to its own copy instead of someone else's.
    @Test
    func sharedLocationIsDerivedFromTheCurrentHomeDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        guard LocalWhisperPaths.modelFolder.contains("huggingface") else { return }
        #expect(LocalWhisperPaths.modelFolder.hasPrefix(home))
    }

    @Test
    func resolvedPathAlwaysNamesTheExpectedModel() {
        #expect(LocalWhisperPaths.modelFolder.contains(LocalWhisperPaths.expectedModelIdentifier))
    }

    /// A missing model must report the writable shared path, not a read-only bundle the user
    /// cannot drop a model into.
    @Test
    func validationErrorPointsAtAUsableLocation() {
        guard let error = LocalWhisperPaths.validationError() else { return }

        #expect(error.contains("huggingface") || error.contains(LocalWhisperPaths.expectedModelIdentifier))
    }
}
