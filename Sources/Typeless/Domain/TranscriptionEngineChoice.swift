import Foundation

/// Which speech engine the user wants NoType to transcribe with.
///
/// - `r2t2` is the local model: Confucius4-R2T2 through llama.cpp and Metal. It detects the spoken
///   language itself, handles mixed Chinese and English, and transcribes while the user speaks.
/// - `appleSpeech` is faster for single-language dictation, but a transcriber is built for exactly
///   one language. It cannot detect what is being spoken.
enum TranscriptionEngineChoice: String, CaseIterable, Equatable {
    case r2t2
    case appleSpeech

    /// macOS 26 is where `SpeechAnalyzer` first ships. Below it there is nothing to choose between.
    static var isAppleSpeechAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// R2T2 handles every recognition mode, so it is the engine a new install starts with.
    static let defaultChoice: TranscriptionEngineChoice = .r2t2

    /// Reads a saved preference. Every removed engine (Whisper, Qwen3-ASR, SenseVoice) was a
    /// multilingual local model, and R2T2 is the local model that replaced them.
    static func savedChoice(rawValue: String) -> TranscriptionEngineChoice? {
        switch rawValue {
        case "bundledWhisper", "qwen3ASR", "senseVoice":
            .r2t2
        default:
            TranscriptionEngineChoice(rawValue: rawValue)
        }
    }

    var menuTitle: String {
        switch self {
        case .r2t2:
            "R2T2 Streaming"
        case .appleSpeech:
            "macOS Speech (fast)"
        }
    }

    var statusDescription: String {
        switch self {
        case .r2t2:
            "Confucius4-R2T2 Q4_K_M streaming model"
        case .appleSpeech:
            "macOS on-device speech"
        }
    }

    /// macOS Speech is bound to one locale, so `Auto` — and every mode on a Mac without macOS
    /// Speech — uses R2T2.
    func resolvedEngine(for language: DictationRecognitionLanguage) -> TranscriptionEngineChoice {
        guard self == .appleSpeech else { return self }
        guard Self.isAppleSpeechAvailable else { return .r2t2 }

        switch language {
        case .mixed:
            return .r2t2
        case .chinese, .english:
            return .appleSpeech
        }
    }
}
