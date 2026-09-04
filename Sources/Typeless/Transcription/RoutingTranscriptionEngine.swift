import Foundation

/// Sends each dictation to the engine that can actually handle it.
///
/// The routing rule lives in `TranscriptionEngineChoice.resolvedEngine(for:)`: the user picks a
/// preferred engine, but `Auto` always falls to Whisper because only Whisper detects the spoken
/// language. Everything else honours the preference.
///
/// Whisper is built on first use rather than up front. A user who stays on macOS Speech never pays
/// for loading the bundled model, which is the whole reason the fast path is worth having.
@MainActor
final class RoutingTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let appState: AppState
    private let makeAppleEngine: () -> TranscriptionEngine?
    private let makeWhisperEngine: () -> TranscriptionEngine
    private var appleEngine: TranscriptionEngine?
    private var whisperEngine: TranscriptionEngine?

    init(
        appState: AppState,
        makeAppleEngine: @escaping () -> TranscriptionEngine? = {
            if #available(macOS 26.0, *) { return AppleSpeechTranscriptionEngine() }
            return nil
        },
        makeWhisperEngine: @escaping () -> TranscriptionEngine = { WhisperKitTranscriptionEngine() }
    ) {
        self.appState = appState
        self.makeAppleEngine = makeAppleEngine
        self.makeWhisperEngine = makeWhisperEngine
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

    /// Warms only the engine the current settings would actually use. Warming both would load the
    /// bundled Whisper model for users who never reach it.
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
                // Only reachable if the availability check and the factory disagree; Whisper is
                // always a working answer, so fall through rather than fail the dictation.
                AppLogger.log("Routing: macOS Speech unavailable, falling back to the bundled model")
                return engine(for: .bundledWhisper)
            }
            bindReadiness(of: created)
            appleEngine = created
            return created

        case .bundledWhisper:
            if let whisperEngine { return whisperEngine }
            let created = makeWhisperEngine()
            bindReadiness(of: created)
            whisperEngine = created
            return created
        }
    }

    /// Both engines report their own preparation lifecycle, and whichever ran most recently is the
    /// one the Diagnostics menu should be describing.
    private func bindReadiness(of engine: TranscriptionEngine) {
        guard let reporter = engine as? LocalModelReadinessReporting else { return }
        reporter.onModelReadinessChange = { [weak self] readiness in
            self?.onModelReadinessChange?(readiness)
        }
    }
}
