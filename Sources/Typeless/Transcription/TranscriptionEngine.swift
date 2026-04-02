@MainActor
protocol TranscriptionEngine {
    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult
}
