import Foundation

/// Which speech engine the user wants NoType to transcribe with.
///
/// The engines make different trade-offs, so none is strictly better:
///
/// - `appleSpeech` is far faster and never translates or invents subtitle sign-offs, but a
///   transcriber is built for exactly one language. It cannot detect what is being spoken.
/// - `qwen3ASR` detects the spoken language on its own through the official sherpa-onnx
///   Qwen3-ASR 0.6B INT8 offline model.
/// - `senseVoice` detects the spoken language for Chinese, Cantonese, English, Japanese, and
///   Korean through a shared local ONNX model.
enum TranscriptionEngineChoice: String, CaseIterable, Equatable {
    case appleSpeech
    case qwen3ASR
    case senseVoice

    /// macOS 26 is where `SpeechAnalyzer` first ships. Below it there is nothing to choose between.
    static var isAppleSpeechAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    static var defaultChoice: TranscriptionEngineChoice {
        isAppleSpeechAvailable ? .appleSpeech : .qwen3ASR
    }

    var menuTitle: String {
        switch self {
        case .appleSpeech:
            "macOS Speech (fast)"
        case .qwen3ASR:
            "Qwen3-ASR 0.6B INT8"
        case .senseVoice:
            "SenseVoice Small"
        }
    }

    var statusDescription: String {
        switch self {
        case .appleSpeech:
            "macOS on-device speech"
        case .qwen3ASR:
            "Qwen3-ASR 0.6B INT8 model"
        case .senseVoice:
            "SenseVoice Small model"
        }
    }

    /// `Auto` asks the selected local model to work out the language. macOS Speech is the one
    /// exception: its recognizer is bound to one locale, so mixed speech uses Qwen3-ASR for the
    /// multilingual local-model behavior.
    func resolvedEngine(for language: DictationRecognitionLanguage) -> TranscriptionEngineChoice {
        guard self == .appleSpeech else { return self }
        guard Self.isAppleSpeechAvailable else { return .qwen3ASR }

        switch language {
        case .mixed:
            return .qwen3ASR
        case .chinese, .english:
            return .appleSpeech
        }
    }
}
