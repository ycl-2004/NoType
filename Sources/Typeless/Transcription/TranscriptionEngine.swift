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

/// An engine that can consume PCM while the microphone is still recording.
///
/// The sink is deliberately returned by `beginStreaming` instead of exposing an `append` method.
/// Audio callbacks arrive on AVAudioEngine's realtime thread, while the engine itself is owned by
/// the main actor. The returned sendable closure is the isolation boundary between those worlds.
@MainActor
protocol StreamingTranscriptionEngine: TranscriptionEngine {
    var canStream: Bool { get }

    func beginStreaming(
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> @Sendable ([Float]) -> Void

    func finishStreaming() async throws -> TranscriptResult
    func cancelStreaming()
}

extension TranscriptionEngine {
    func prewarm() async {}
}
