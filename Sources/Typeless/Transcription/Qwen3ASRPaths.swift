import Foundation

/// Paths for the official sherpa-onnx Qwen3-ASR 0.6B INT8 model.
enum Qwen3ASRPaths {
    static let modelPackageName = "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25"
    static let archiveFileName = "\(modelPackageName).tar.bz2"
    static let modelDownloadURL = URL(
        string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/\(archiveFileName)"
    )!

    static let convFrontendFileName = "conv_frontend.onnx"
    static let encoderFileName = "encoder.int8.onnx"
    static let decoderFileName = "decoder.int8.onnx"
    static let tokenizerDirectoryName = "tokenizer"

    /// `AudioChunker` keeps every decode inside the range this model handles, so these bound one
    /// chunk rather than a whole recording. 512 is the official default and was measured correct for
    /// a 31s clip; 1024 is headroom for a chunk denser than the samples that were measured, and cost
    /// nothing on short clips in the same sweep (identical text, identical decode time).
    static let maxTotalLength = 1024
    static let maxNewTokens = 512
    static let temperature: Float = 1e-6
    static let topP: Float = 0.8
    static let seed = 42

    static var sharedModelBaseFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/k2-fsa", isDirectory: true)
    }

    static var modelFolder: URL {
        sharedModelBaseFolder.appendingPathComponent(modelPackageName, isDirectory: true)
    }

    static var convFrontendURL: URL {
        modelFolder.appendingPathComponent(convFrontendFileName)
    }

    static var encoderURL: URL {
        modelFolder.appendingPathComponent(encoderFileName)
    }

    static var decoderURL: URL {
        modelFolder.appendingPathComponent(decoderFileName)
    }

    static var tokenizerURL: URL {
        modelFolder.appendingPathComponent(tokenizerDirectoryName, isDirectory: true)
    }

    static var modelFolderExists: Bool {
        requiredPaths.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func validationError() -> String? {
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            return "Qwen3-ASR model is missing at \(displayPath(modelFolder))"
        }

        let requiredFiles: [(URL, String)] = [
            (convFrontendURL, convFrontendFileName),
            (encoderURL, encoderFileName),
            (decoderURL, decoderFileName),
            (tokenizerURL, tokenizerDirectoryName),
        ]
        for (url, name) in requiredFiles where FileManager.default.fileExists(atPath: url.path) == false {
            return "Qwen3-ASR model file is missing: \(name) at \(displayPath(url))"
        }

        guard encoderURL.lastPathComponent.contains("int8"),
              decoderURL.lastPathComponent.contains("int8") else {
            return "Qwen3-ASR model is not the expected INT8 package at \(displayPath(modelFolder))"
        }

        return nil
    }

    static func displayPath(_ url: URL) -> String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    private static var requiredPaths: [URL] {
        [convFrontendURL, encoderURL, decoderURL, tokenizerURL]
    }
}
