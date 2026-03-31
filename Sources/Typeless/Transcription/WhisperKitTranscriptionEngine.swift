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
            AppLogger.log("WhisperKit: attempt \(String(describing: attempt.kind)) raw result: \(result)")

            if Self.shouldRetryAfterTranscriptionResult(result) {
                AppLogger.log("WhisperKit: empty transcription result, retrying next fallback if available")
            }
        }

        if let bestResult = Self.selectBestTranscript(from: attemptResults, preferredLanguage: language),
           !Self.shouldRetryAfterTranscriptionResult(bestResult.text) {
            let cleanedText = TranscriptPostProcessor.clean(bestResult.text, preferredLanguage: language)
            AppLogger.log(
                "WhisperKit: selected best transcript from \(attemptResults.count) attempts using \(String(describing: bestResult.attempt.kind)); " +
                "raw=\"\(bestResult.text)\" cleaned=\"\(cleanedText)\""
            )
            return TranscriptResult(text: cleanedText, rawText: bestResult.text)
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
            return [
                TranscriptionAttempt(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                TranscriptionAttempt(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                TranscriptionAttempt(kind: .forcedEnglish, languageCode: "en", detectLanguage: false)
            ]
        case .english:
            return [
                TranscriptionAttempt(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                TranscriptionAttempt(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                TranscriptionAttempt(kind: .forcedChinese, languageCode: "zh", detectLanguage: false)
            ]
        }
    }

    nonisolated static func makeDecodingOptions(
        for attempt: TranscriptionAttempt,
        tokenizer: WhisperTokenizer? = nil
    ) -> DecodingOptions {
        return DecodingOptions(
            verbose: true,
            task: .transcribe,
            language: attempt.languageCode,
            usePrefillPrompt: true,
            detectLanguage: attempt.detectLanguage,
            promptTokens: nil
        )
    }

    nonisolated static func promptText(for attempt: TranscriptionAttempt) -> String {
        switch attempt.kind {
        case .autoDetect:
            mixedPromptText
        case .forcedChinese:
            """
            This is primarily Chinese dictation.
            English words, names, and technical terms may appear.
            Do not translate.
            Preserve any English words exactly as spoken.
            这是以中文为主的语音转写。
            其中可能夹杂英文单词、人名或技术词。
            不要翻译，按原话输出。
            """
        case .forcedEnglish:
            """
            This is primarily English dictation.
            Chinese words, names, and short phrases may appear.
            Do not translate.
            Preserve any Chinese words exactly as spoken.
            This may contain code-switching.
            """
        }
    }

    nonisolated static func encodedPromptTokens(
        for attempt: TranscriptionAttempt,
        tokenizer: WhisperTokenizer?
    ) -> [Int]? {
        guard let tokenizer else {
            return nil
        }

        return tokenizer
            .encode(text: " " + promptText(for: attempt).trimmingCharacters(in: .whitespacesAndNewlines))
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
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
        let latinCount = scalarView.filter { CharacterSet.letters.contains($0) && $0.value < 128 }.count
        let cjkCount = scalarView.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let repetitionPenalty = repeatedFragmentPenalty(in: trimmed)
        let mixedBonus = hasLatin && hasCJK ? 220 : 0
        let englishSentencePenalty = englishDominantPenalty(in: trimmed, latinCount: latinCount, cjkCount: cjkCount)
        let chineseSentencePenalty = chineseDominantPenalty(in: trimmed, latinCount: latinCount, cjkCount: cjkCount)

        switch language {
        case .mixed:
            let multilingualBonus = hasLatin || hasCJK ? 100 : -200
            return mixedBonus + multilingualBonus + contentLength + min(latinCount, 40) + min(cjkCount * 2, 80) - repetitionPenalty
        case .chinese:
            let cjkBonus = hasCJK ? 260 : -260
            let mixedLanguageSupport = hasLatin && hasCJK ? 120 : 0
            return cjkBonus + mixedLanguageSupport + (cjkCount * 4) + latinCount + contentLength - repetitionPenalty - englishSentencePenalty
        case .english:
            let latinBonus = hasLatin ? 260 : -260
            let mixedLanguageSupport = hasLatin && hasCJK ? 120 : 0
            return latinBonus + mixedLanguageSupport + (latinCount * 4) + cjkCount + contentLength - repetitionPenalty - chineseSentencePenalty
        }
    }

    nonisolated static func repeatedFragmentPenalty(in text: String) -> Int {
        let tokens = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map { $0.lowercased() }

        guard tokens.count > 1 else {
            return 0
        }

        var penalty = 0
        for index in 1..<tokens.count where tokens[index] == tokens[index - 1] {
            penalty += 40
        }
        return penalty
    }

    nonisolated static func englishDominantPenalty(in text: String, latinCount: Int, cjkCount: Int) -> Int {
        guard latinCount > 0 else {
            return 0
        }

        var penalty = 0
        if cjkCount <= 2, latinCount >= 18 {
            penalty += 420
        }
        if latinCount > max(cjkCount * 3, 12) {
            penalty += 220
        }
        if text.contains("I want to ") || text.contains("Let's ") || text.contains("Now ") {
            penalty += 120
        }
        return penalty
    }

    nonisolated static func chineseDominantPenalty(in text: String, latinCount: Int, cjkCount: Int) -> Int {
        guard cjkCount > 0 else {
            return 0
        }

        var penalty = 0
        if latinCount <= 2, cjkCount >= 12 {
            penalty += 420
        }
        if cjkCount > max(latinCount * 3, 12) {
            penalty += 220
        }
        if text.contains("我想") || text.contains("現在") || text.contains("可以嗎") {
            penalty += 80
        }
        return penalty
    }

    private func loadPipeline() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }

        if let validationError = LocalWhisperPaths.validationError() {
            AppLogger.log("WhisperKit: model validation failed: \(validationError)")
            throw TranscriptionError.modelUnavailable(validationError)
        }

        AppLogger.log(
            "WhisperKit: loading validated local model \(LocalWhisperPaths.expectedModelIdentifier) from \(LocalWhisperPaths.modelFolder)"
        )
        let config = WhisperKitConfig(
            modelFolder: LocalWhisperPaths.modelFolder,
            tokenizerFolder: LocalWhisperPaths.tokenizerBaseFolder,
            verbose: true,
            logLevel: .debug,
            load: true,
            download: false
        )

        let pipeline = try await WhisperKit(config)
        whisperKit = pipeline
        AppLogger.log("WhisperKit: pipeline loaded successfully")
        return pipeline
    }
}
