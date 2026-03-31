@MainActor
protocol TranscriptionEngine {
    func transcribe(_ clip: RecordedAudioClip, language: DictationRecognitionLanguage) async throws -> TranscriptResult
}
