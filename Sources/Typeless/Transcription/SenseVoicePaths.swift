import Foundation

/// The single shared SenseVoice installation used by NoType.
///
/// SenseVoice is deliberately kept outside the app bundle. A stable location avoids a second copy
/// for every build and lets other local speech tools reuse the same model files.
enum SenseVoicePaths {
    static let modelPackageName = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
    static let modelFileName = "model.int8.onnx"
    static let tokensFileName = "tokens.txt"
    static let archiveFileName = "\(modelPackageName).tar.bz2"
    static let modelDownloadURL = URL(
        string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(archiveFileName)"
    )!

    static var sharedModelBaseFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/k2-fsa", isDirectory: true)
    }

    static var modelFolder: URL {
        sharedModelBaseFolder.appendingPathComponent(modelPackageName, isDirectory: true)
    }

    static var modelURL: URL {
        modelFolder.appendingPathComponent(modelFileName)
    }

    static var tokensURL: URL {
        modelFolder.appendingPathComponent(tokensFileName)
    }

    static var modelFolderExists: Bool {
        FileManager.default.fileExists(atPath: modelURL.path) &&
            FileManager.default.fileExists(atPath: tokensURL.path)
    }

    static func validationError() -> String? {
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            return "SenseVoice model is missing at \(displayPath(modelFolder))"
        }
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return "SenseVoice model file is missing at \(displayPath(modelURL))"
        }
        guard FileManager.default.fileExists(atPath: tokensURL.path) else {
            return "SenseVoice tokenizer is missing at \(displayPath(tokensURL))"
        }
        return nil
    }

    static func displayPath(_ url: URL) -> String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
}
