import Foundation

enum LocalWhisperPaths {
    static let expectedModelIdentifier = "large-v3"
    static let modelFolder = "/Users/yichenlin/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930"
    static let tokenizerBaseFolder = URL(fileURLWithPath: "/Users/yichenlin/Documents/huggingface")

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
