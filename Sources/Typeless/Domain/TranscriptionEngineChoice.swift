import Foundation

/// Which speech engine the user wants NoType to transcribe with.
///
/// The engines make different trade-offs, so none is strictly better:
///
/// - `appleSpeech` is far faster and never translates or invents subtitle sign-offs, but a
///   transcriber is built for exactly one language. It cannot detect what is being spoken.
/// - `bundledWhisper` detects the spoken language on its own and keeps the existing mixed-language
///   behavior, at the cost of latency and the occasional hallucinated closer.
/// - `senseVoice` detects the spoken language for Chinese, Cantonese, English, Japanese, and
///   Korean through a shared local ONNX model.
enum TranscriptionEngineChoice: String, CaseIterable, Equatable {
    case appleSpeech
    case bundledWhisper
    case senseVoice

    /// macOS 26 is where `SpeechAnalyzer` first ships. Below it there is nothing to choose between.
    static var isAppleSpeechAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    static var defaultChoice: TranscriptionEngineChoice {
        isAppleSpeechAvailable ? .appleSpeech : .bundledWhisper
    }

    var menuTitle: String {
        switch self {
        case .appleSpeech:
            "macOS Speech (fast)"
        case .bundledWhisper:
            "Bundled Whisper"
        case .senseVoice:
            "SenseVoice Small"
        }
    }

    var statusDescription: String {
        switch self {
        case .appleSpeech:
            "macOS on-device speech"
        case .bundledWhisper:
            "bundled Whisper model"
        case .senseVoice:
            "SenseVoice Small model"
        }
    }

    /// `Auto` asks the selected local model to work out the language. macOS Speech is the one
    /// exception: its recognizer is bound to one locale, so mixed speech uses Whisper for the
    /// existing default behavior.
    func resolvedEngine(for language: DictationRecognitionLanguage) -> TranscriptionEngineChoice {
        guard self == .appleSpeech else { return self }
        guard Self.isAppleSpeechAvailable else { return .bundledWhisper }

        switch language {
        case .mixed:
            return .bundledWhisper
        case .chinese, .english:
            return .appleSpeech
        }
    }
}
