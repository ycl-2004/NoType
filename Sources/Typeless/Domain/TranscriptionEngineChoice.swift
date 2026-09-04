import Foundation

/// Which speech engine the user wants NoType to transcribe with.
///
/// The two engines fail in opposite directions, so neither is strictly better:
///
/// - `appleSpeech` is far faster and never translates or invents subtitle sign-offs, but a
///   transcriber is built for exactly one language. It cannot detect what is being spoken.
/// - `bundledWhisper` detects the spoken language on its own, which is the only way `Auto` can
///   work, at the cost of latency and the occasional hallucinated closer.
enum TranscriptionEngineChoice: String, CaseIterable, Equatable {
    case appleSpeech
    case bundledWhisper

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
        }
    }

    var statusDescription: String {
        switch self {
        case .appleSpeech:
            "macOS on-device speech"
        case .bundledWhisper:
            "bundled Whisper model"
        }
    }

    /// `Auto` asks the engine to work out the language from the audio, which only Whisper can do.
    /// Picking macOS Speech for a mixed recording would force one language onto the whole clip and
    /// transliterate the rest — Chinese spoken into an English model comes back as pinyin.
    func resolvedEngine(for language: DictationRecognitionLanguage) -> TranscriptionEngineChoice {
        guard self == .appleSpeech, Self.isAppleSpeechAvailable else { return .bundledWhisper }

        switch language {
        case .mixed:
            return .bundledWhisper
        case .chinese, .english:
            return .appleSpeech
        }
    }
}
