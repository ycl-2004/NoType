import Foundation

enum LocalWhisperPaths {
    static let modelFolder = "/Users/yichenlin/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930"
    static let tokenizerBaseFolder = URL(fileURLWithPath: "/Users/yichenlin/Documents/huggingface")

    static var modelFolderExists: Bool {
        FileManager.default.fileExists(atPath: modelFolder)
    }
}
