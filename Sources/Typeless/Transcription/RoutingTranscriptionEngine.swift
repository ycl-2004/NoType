import Foundation

/// Sends each dictation to the engine that can actually handle it.
///
/// The routing rule lives in `TranscriptionEngineChoice.resolvedEngine(for:)`: local model choices
/// are honored for every recognition mode, while macOS Speech falls back to Qwen3-ASR for mixed
/// speech because its recognizer is bound to one locale.
///
/// Each model-backed engine is built on first use rather than up front. A user who stays on macOS
/// Speech never pays for loading either local model, which is the whole reason the fast path is
/// worth having.
@MainActor
final class RoutingTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let appState: AppState
    private let makeAppleEngine: () -> TranscriptionEngine?
    private let makeQwen3ASREngine: () -> TranscriptionEngine
    private let makeSenseVoiceEngine: () -> TranscriptionEngine
    private var appleEngine: TranscriptionEngine?
    private var qwen3ASREngine: TranscriptionEngine?
    private var senseVoiceEngine: TranscriptionEngine?

    init(
        appState: AppState,
        makeAppleEngine: @escaping () -> TranscriptionEngine? = {
            if #available(macOS 26.0, *) { return AppleSpeechTranscriptionEngine() }
            return nil
        },
        makeQwen3ASREngine: @escaping () -> TranscriptionEngine = { Qwen3ASRTranscriptionEngine() },
        makeSenseVoiceEngine: @escaping () -> TranscriptionEngine = { SenseVoiceTranscriptionEngine() }
    ) {
        self.appState = appState
        self.makeAppleEngine = makeAppleEngine
        self.makeQwen3ASREngine = makeQwen3ASREngine
        self.makeSenseVoiceEngine = makeSenseVoiceEngine
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let choice = appState.selectedTranscriptionEngine.resolvedEngine(for: language)
        AppLogger.log(
            "Routing: \(language.statusDescription) with \(appState.selectedTranscriptionEngine.statusDescription) " +
            "preference resolved to \(choice.statusDescription)"
        )

        return try await engine(for: choice).transcribe(
            clip,
            language: language,
            chineseScriptPreference: chineseScriptPreference
        )
    }

    /// Warms only the engine the current settings would actually use. Warming both would load a
    /// large local model for users who never reach it.
    func prewarm() async {
        let choice = appState.selectedTranscriptionEngine.resolvedEngine(
            for: appState.selectedRecognitionLanguage
        )
        AppLogger.log("Routing.prewarm: preparing \(choice.statusDescription)")
        await engine(for: choice).prewarm()
    }

    private func engine(for choice: TranscriptionEngineChoice) -> TranscriptionEngine {
        switch choice {
        case .appleSpeech:
            if let appleEngine { return appleEngine }
            guard let created = makeAppleEngine() else {
                // Only reachable if the availability check and the factory disagree; Qwen3-ASR is
                // always a working local answer, so fall through rather than fail the dictation.
                AppLogger.log("Routing: macOS Speech unavailable, falling back to Qwen3-ASR")
                return engine(for: .qwen3ASR)
            }
            bindReadiness(of: created)
            appleEngine = created
            return created

        case .qwen3ASR:
            if let qwen3ASREngine { return qwen3ASREngine }
            let created = makeQwen3ASREngine()
            bindReadiness(of: created)
            qwen3ASREngine = created
            return created

        case .senseVoice:
            if let senseVoiceEngine { return senseVoiceEngine }
            let created = makeSenseVoiceEngine()
            bindReadiness(of: created)
            senseVoiceEngine = created
            return created
        }
    }

    /// Each local engine reports its own preparation lifecycle, and whichever ran most recently is
    /// the one the Diagnostics menu should be describing.
    private func bindReadiness(of engine: TranscriptionEngine) {
        guard let reporter = engine as? LocalModelReadinessReporting else { return }
        reporter.onModelReadinessChange = { [weak self] readiness in
            self?.onModelReadinessChange?(readiness)
        }
    }
}
