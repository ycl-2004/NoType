import Foundation

/// Sends each dictation to the engine that can actually handle it.
///
/// The routing rule lives in `TranscriptionEngineChoice.resolvedEngine(for:)`: R2T2 is honored for
/// every recognition mode, while macOS Speech falls back to R2T2 for mixed speech because its
/// recognizer is bound to one locale.
///
/// Each engine is built on first use rather than up front. A user who stays on macOS Speech never
/// pays for loading the local model, which is the whole reason the fast path is worth having.
@MainActor
final class RoutingTranscriptionEngine: StreamingTranscriptionEngine, LocalModelReadinessReporting {
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    private let appState: AppState
    private let makeAppleEngine: () -> TranscriptionEngine?
    private let makeR2T2Engine: () -> TranscriptionEngine
    private var appleEngine: TranscriptionEngine?
    private var r2t2Engine: TranscriptionEngine?
    private var activeStreamingEngine: StreamingTranscriptionEngine?

    /// Streams whenever the dictation will reach R2T2, including `Auto` while macOS Speech is the
    /// preference, so the fallback keeps the streaming stop latency too.
    var canStream: Bool {
        appState.selectedTranscriptionEngine
            .resolvedEngine(for: appState.selectedRecognitionLanguage) == .r2t2
    }

    init(
        appState: AppState,
        makeAppleEngine: @escaping () -> TranscriptionEngine? = {
            if #available(macOS 26.0, *) { return AppleSpeechTranscriptionEngine() }
            return nil
        },
        makeR2T2Engine: (() -> TranscriptionEngine)? = nil
    ) {
        self.appState = appState
        self.makeAppleEngine = makeAppleEngine
        self.makeR2T2Engine = makeR2T2Engine ?? { R2T2TranscriptionEngine(appState: appState) }
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
    /// local model for users who never reach it.
    func prewarm() async {
        guard activeStreamingEngine == nil else { return }
        let choice = appState.selectedTranscriptionEngine.resolvedEngine(
            for: appState.selectedRecognitionLanguage
        )
        AppLogger.log("Routing.prewarm: preparing \(choice.statusDescription)")
        await engine(for: choice).prewarm()
    }

    func beginStreaming(
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> @Sendable ([Float]) -> Void {
        guard canStream,
              let engine = engine(for: .r2t2) as? StreamingTranscriptionEngine,
              engine.canStream else {
            throw TranscriptionError.engineUnavailable
        }
        let sink = try await engine.beginStreaming(
            language: language,
            chineseScriptPreference: chineseScriptPreference
        )
        activeStreamingEngine = engine
        return sink
    }

    func finishStreaming() async throws -> TranscriptResult {
        guard let activeStreamingEngine else {
            throw TranscriptionError.failed("Streaming transcription session is missing")
        }
        defer { self.activeStreamingEngine = nil }
        return try await activeStreamingEngine.finishStreaming()
    }

    func cancelStreaming() {
        activeStreamingEngine?.cancelStreaming()
        activeStreamingEngine = nil
    }

    private func engine(for choice: TranscriptionEngineChoice) -> TranscriptionEngine {
        // Keep the current engine hot, but do not accumulate every model used in this process.
        // An in-flight stream retains its engine until finalization/cancellation.
        if activeStreamingEngine == nil {
            if choice != .appleSpeech { appleEngine = nil }
            if choice != .r2t2 { r2t2Engine = nil }
        }
        switch choice {
        case .appleSpeech:
            if let appleEngine { return appleEngine }
            guard let created = makeAppleEngine() else {
                // Only reachable if the availability check and the factory disagree; R2T2 is
                // always a working local answer, so fall through rather than fail the dictation.
                AppLogger.log("Routing: macOS Speech unavailable, falling back to R2T2")
                return engine(for: .r2t2)
            }
            bindReadiness(of: created)
            appleEngine = created
            return created

        case .r2t2:
            if let r2t2Engine { return r2t2Engine }
            let created = makeR2T2Engine()
            bindReadiness(of: created)
            r2t2Engine = created
            return created
        }
    }

    /// An engine that loads a model reports its own preparation lifecycle, and whichever ran most
    /// recently is the one the Diagnostics menu should be describing.
    private func bindReadiness(of engine: TranscriptionEngine) {
        guard let reporter = engine as? LocalModelReadinessReporting else { return }
        reporter.onModelReadinessChange = { [weak self] readiness in
            self?.onModelReadinessChange?(readiness)
        }
    }
}
