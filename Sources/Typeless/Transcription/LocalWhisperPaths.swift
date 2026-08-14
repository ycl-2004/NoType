import Foundation

enum LocalWhisperPaths {
    static let expectedModelIdentifier = "large-v3"
    private static let bundledModelFolderName = "openai_whisper-large-v3-v20240930"
    private static let bundledTokenizerRelativePath = "models/openai/whisper-large-v3/tokenizer.json"
    private static let developerModelFolder = "/Users/yichenlin/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930"
    private static let developerTokenizerBaseFolder = URL(fileURLWithPath: "/Users/yichenlin/Documents/huggingface")

    static let modelFolder: String = {
        guard let bundledModelFolder = Bundle.main.resourceURL?.appendingPathComponent(bundledModelFolderName),
              FileManager.default.fileExists(atPath: bundledModelFolder.path) else {
            return developerModelFolder
        }
        return bundledModelFolder.path
    }()

    static let tokenizerBaseFolder: URL = {
        guard let resourceURL = Bundle.main.resourceURL,
              FileManager.default.fileExists(
                  atPath: resourceURL.appendingPathComponent(bundledTokenizerRelativePath).path
              ) else {
            return developerTokenizerBaseFolder
        }
        return resourceURL
    }()

    static var modelFolderExists: Bool {
        FileManager.default.fileExists(atPath: modelFolder)
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
