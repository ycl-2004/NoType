import Foundation

/// Paths for the experimental Confucius4-R2T2 GGUF package.
///
/// The model and its audio projector stay outside the app bundle so replacing NoType does not
/// duplicate a roughly 1.6 GB download. The files are kept under the Hugging Face model folder
/// rather than the sherpa-onnx folder because they come from a different runtime and publisher.
enum R2T2Paths {
    static let modelRepository = "mradermacher/Confucius4-R2T2-GGUF"
    static let modelPackageName = "Confucius4-R2T2-GGUF"
    static let modelFileName = "Confucius4-R2T2.Q4_K_M.gguf"
    static let projectorFileName = "Confucius4-R2T2.mmproj-Q8_0.gguf"

    static let modelDownloadURL = URL(
        string: "https://huggingface.co/\(modelRepository)/resolve/main/\(modelFileName)"
    )!
    static let projectorDownloadURL = URL(
        string: "https://huggingface.co/\(modelRepository)/resolve/main/\(projectorFileName)"
    )!

    /// NoType's first R2T2 experiment intentionally uses the higher-quality projector quant.
    static let chunkDurationMilliseconds = 320
    static let sampleRate = 16_000
    static let modelQuantization = "Q4_K_M"
    static let projectorQuantization = "Q8_0"

    static var sharedModelBaseFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/mradermacher", isDirectory: true)
    }

    /// R2T2 must remain in NoType's shared Hugging Face model store. A cache, app-support folder,
    /// or symlink to an unrelated location would violate the model download contract.
    static var huggingFaceFolder: URL {
        HuggingFaceModelStore.root
    }

    static var modelFolder: URL {
        sharedModelBaseFolder.appendingPathComponent(modelPackageName, isDirectory: true)
    }

    static var modelURL: URL {
        modelFolder.appendingPathComponent(modelFileName)
    }

    static var projectorURL: URL {
        modelFolder.appendingPathComponent(projectorFileName)
    }

    static var modelFolderExists: Bool {
        locationValidationError() == nil
            && requiredPaths.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func validationError() -> String? {
        if let locationError = locationValidationError() {
            return locationError
        }
        guard fileManager.fileExists(atPath: modelFolder.path) else {
            return "R2T2 model is missing at \(displayPath(modelFolder))"
        }

        let requiredFiles: [(URL, String)] = [
            (modelURL, modelFileName),
            (projectorURL, projectorFileName),
        ]
        for (url, name) in requiredFiles where fileManager.fileExists(atPath: url.path) == false {
            return "R2T2 model file is missing: \(name) at \(displayPath(url))"
        }

        guard modelURL.pathExtension.lowercased() == "gguf",
              projectorURL.pathExtension.lowercased() == "gguf" else {
            return "R2T2 model files must use the GGUF format."
        }

        return nil
    }

    /// Check the configured path and its resolved filesystem path. This rejects a model folder or
    /// file that is presented under huggingface but actually stores bytes somewhere else.
    static func locationValidationError() -> String? {
        guard let baseError = HuggingFaceModelStore.locationValidationError(for: sharedModelBaseFolder) else {
            return HuggingFaceModelStore.locationValidationError(
                for: modelFolder,
                requiredPaths: requiredPaths
            )
        }
        return baseError
    }

    static func displayPath(_ url: URL) -> String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    private static var requiredPaths: [URL] {
        [modelURL, projectorURL]
    }

    private static var fileManager: FileManager { .default }
}
