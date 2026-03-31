import Foundation
@preconcurrency import WhisperKit

@MainActor
final class WhisperKitTranscriptionEngine: TranscriptionEngine {
    struct TranscriptionAttempt: Equatable {
        let kind: AttemptKind
        let languageCode: String?
        let detectLanguage: Bool

        enum AttemptKind: Equatable {
            case autoDetect
            case forcedChinese
            case forcedEnglish
        }
    }

    struct AttemptResult: Equatable {
        let attempt: TranscriptionAttempt
        let text: String
    }

    private var whisperKit: WhisperKit?
    nonisolated static let mixedBaseLanguageCode = "zh"
    nonisolated static let mixedPromptText = """
    This is a multilingual transcription.
    Do not translate.
    Preserve the original spoken words exactly.
    Chinese and English may appear in the same sentence.
    Keep code-switching as spoken.
    这是中英混合语音转写。
    不要翻译。
    按原话输出。
    同一句里可能同时出现中文和英文。
    """

    func transcribe(_ clip: RecordedAudioClip, language: DictationRecognitionLanguage) async throws -> TranscriptResult {
        let pipeline = try await loadPipeline()
        var attemptResults: [AttemptResult] = []

        for attempt in Self.transcriptionAttempts(for: language) {
            let options = Self.makeDecodingOptions(for: attempt, tokenizer: pipeline.tokenizer)

            AppLogger.log(
                "WhisperKit: transcribing attempt=\(String(describing: attempt.kind)), " +
                "language=\(attempt.languageCode ?? "auto"), " +
                "prefill=\(options.usePrefillPrompt), detectLanguage=\(options.detectLanguage)"
            )

            let results = try await pipeline.transcribe(
                audioPath: clip.fileURL.path,
                decodeOptions: options
            )

            let result = results.first?.text ?? ""
            attemptResults.append(AttemptResult(attempt: attempt, text: result))

            if language != .mixed, !Self.shouldRetryAfterTranscriptionResult(result) {
                AppLogger.log("WhisperKit: transcription succeeded with attempt \(String(describing: attempt.kind))")
                return TranscriptResult(text: result)
            }

            if Self.shouldRetryAfterTranscriptionResult(result) {
                AppLogger.log("WhisperKit: empty transcription result, retrying next fallback if available")
            }
        }

        if let bestResult = Self.selectBestTranscript(from: attemptResults, preferredLanguage: language),
           !Self.shouldRetryAfterTranscriptionResult(bestResult.text) {
            AppLogger.log("WhisperKit: selected best transcript from \(attemptResults.count) attempts using \(String(describing: bestResult.attempt.kind))")
            return TranscriptResult(text: bestResult.text)
        }

        throw TranscriptionError.failed(
            "WhisperKit returned no text" +
            (attemptResults.last.map { " (last raw result: \($0.text))" } ?? "")
        )
    }

    nonisolated static func makeDecodingOptions(
        for language: DictationRecognitionLanguage,
        tokenizer: WhisperTokenizer? = nil
    ) -> DecodingOptions {
        makeDecodingOptions(for: transcriptionAttempts(for: language)[0], tokenizer: tokenizer)
    }

    nonisolated static func transcriptionAttempts(
        for language: DictationRecognitionLanguage
    ) -> [TranscriptionAttempt] {
        switch language {
        case .mixed:
            return [
                TranscriptionAttempt(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                TranscriptionAttempt(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                TranscriptionAttempt(kind: .forcedEnglish, languageCode: "en", detectLanguage: false)
            ]
        case .chinese:
            return [TranscriptionAttempt(kind: .forcedChinese, languageCode: "zh", detectLanguage: false)]
        case .english:
            return [TranscriptionAttempt(kind: .forcedEnglish, languageCode: "en", detectLanguage: false)]
        }
    }

    nonisolated static func makeDecodingOptions(
        for attempt: TranscriptionAttempt,
        tokenizer _: WhisperTokenizer? = nil
    ) -> DecodingOptions {
        DecodingOptions(
            verbose: true,
            task: .transcribe,
            language: attempt.languageCode,
            usePrefillPrompt: true,
            detectLanguage: attempt.detectLanguage,
            promptTokens: nil
        )
    }

    nonisolated static func shouldRetryAfterTranscriptionResult(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    nonisolated static func selectBestTranscript(
        from results: [AttemptResult],
        preferredLanguage: DictationRecognitionLanguage
    ) -> AttemptResult? {
        results
            .filter { !shouldRetryAfterTranscriptionResult($0.text) }
            .max { lhs, rhs in
                transcriptScore(lhs.text, for: preferredLanguage) < transcriptScore(rhs.text, for: preferredLanguage)
            }
    }

    nonisolated static func transcriptScore(
        _ text: String,
        for language: DictationRecognitionLanguage
    ) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Int.min }

        let scalarView = trimmed.unicodeScalars
        let hasLatin = scalarView.contains { CharacterSet.letters.contains($0) && $0.value < 128 }
        let hasCJK = scalarView.contains { (0x4E00...0x9FFF).contains($0.value) }
        let contentLength = trimmed.count

        switch language {
        case .mixed:
            let mixedBonus = hasLatin && hasCJK ? 500 : 0
            let multilingualBonus = hasLatin || hasCJK ? 100 : 0
            return mixedBonus + multilingualBonus + contentLength
        case .chinese:
            return (hasCJK ? 200 : 0) + contentLength
        case .english:
            return (hasLatin ? 200 : 0) + contentLength
        }
    }

    private func loadPipeline() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }

        let config: WhisperKitConfig
        if LocalWhisperPaths.modelFolderExists {
            AppLogger.log("WhisperKit: loading local model from \(LocalWhisperPaths.modelFolder)")
            config = WhisperKitConfig(
                modelFolder: LocalWhisperPaths.modelFolder,
                tokenizerFolder: LocalWhisperPaths.tokenizerBaseFolder,
                verbose: true,
                logLevel: .debug,
                load: true,
                download: false
            )
        } else {
            AppLogger.log("WhisperKit: local model missing, falling back to auto-download")
            config = WhisperKitConfig(
                verbose: true,
                logLevel: .debug,
                load: true,
                download: true
            )
        }

        let pipeline = try await WhisperKit(config)
        whisperKit = pipeline
        AppLogger.log("WhisperKit: pipeline loaded successfully")
        return pipeline
    }
}
