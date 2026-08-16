@MainActor
protocol TranscriptionEngine {
    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult

    /// Loads whatever the first transcription would otherwise have to load. Best effort: failures
    /// are absorbed here so the real attempt can surface them with proper error handling.
    func prewarm() async
}

@MainActor
protocol LocalModelReadinessReporting: AnyObject {
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)? { get set }
}

extension TranscriptionEngine {
    func prewarm() async {}
}
