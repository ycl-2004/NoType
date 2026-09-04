import Foundation

enum LocalWhisperPaths {
    static let expectedModelIdentifier = "large-v3"
    /// The `_turbo` package uses its own optimized compiled model artifacts and adds a
    /// `TextDecoderContextPrefill` model, which lets WhisperKit look up the KV cache for the
    /// leading special tokens instead of decoding them one by one.
    private static let bundledModelFolderName = "openai_whisper-large-v3-v20240930_turbo"
    private static let bundledTokenizerRelativePath = "models/openai/whisper-large-v3/tokenizer.json"
    /// The shared location is checked **before** the app's own copy, and that order is deliberate.
    /// Core ML caches its model specialization per model path. Loading from inside the app bundle
    /// moves that path every time the bundle is replaced, throwing the cache away and costing
    /// minutes on the next launch — measured at 4m13s after one rebuild, against 4s when the path
    /// held still. Preferring a stable location outside the bundle keeps the cache valid, and also
    /// means a developer machine keeps exactly one copy of a 1.5 GB model instead of one per build.
    private static let sharedModelBaseFolder = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/huggingface", isDirectory: true)

    private static let modelRepositoryRelativePath = "models/argmaxinc/whisperkit-coreml"

    private static var sharedModelFolder: URL {
        modelFolder(under: sharedModelBaseFolder)
    }

    /// Where a `downloadBase` puts the model, mirroring the layout `WhisperKit.download` creates.
    static func modelFolder(under downloadBase: URL) -> URL {
        downloadBase
            .appendingPathComponent(modelRepositoryRelativePath, isDirectory: true)
            .appendingPathComponent(bundledModelFolderName, isDirectory: true)
    }

    /// Every place the model may legitimately live, in the order they are searched. Install
    /// locations come before the app bundle so a user who downloaded the model keeps one copy and
    /// one stable Core ML cache, whichever build of the app is installed over the top.
    static var searchedModelFolders: [URL] {
        var folders = ModelInstallLocation.allCases.map { modelFolder(under: $0.downloadBase) }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent(bundledModelFolderName) {
            folders.append(bundled)
        }
        return folders
    }

    /// Recomputed rather than cached: a model downloaded during this launch has to be visible to
    /// the load that follows it, without restarting the app.
    static var modelFolder: String {
        for candidate in searchedModelFolders where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }

        // Nothing found. Name the shared path, which the user can actually write to, instead of a
        // signed app bundle they cannot drop a model into.
        return sharedModelFolder.path
    }

    static var tokenizerBaseFolder: URL {
        // Same order as the model, so both resolve to one consistent install.
        var bases = ModelInstallLocation.allCases.map(\.downloadBase)
        if let resourceURL = Bundle.main.resourceURL {
            bases.append(resourceURL)
        }

        for base in bases where FileManager.default.fileExists(
            atPath: base.appendingPathComponent(bundledTokenizerRelativePath).path
        ) {
            return base
        }

        return sharedModelBaseFolder
    }

    static var modelFolderExists: Bool {
        FileManager.default.fileExists(atPath: modelFolder)
    }

    /// WhisperKit silently falls back to decoding the prefill tokens when this model is absent, so
    /// the load path logs it rather than letting a missing folder quietly cost speed.
    static var hasContextPrefill: Bool {
        FileManager.default.fileExists(
            atPath: (modelFolder as NSString).appendingPathComponent("TextDecoderContextPrefill.mlmodelc")
        )
    }

    static func validationError() -> String? {
        guard modelFolderExists else {
            return "Required Whisper model is missing at \(modelFolder)"
        }

        guard modelFolder.localizedCaseInsensitiveContains(expectedModelIdentifier) else {
            return "Expected Whisper model path containing \(expectedModelIdentifier), got \(modelFolder)"
        }

        return nil
    }
}
