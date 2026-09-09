import Foundation
@preconcurrency import WhisperKit

@MainActor
final class WhisperKitTranscriptionEngine: TranscriptionEngine, LocalModelReadinessReporting {
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

    struct TranscriptFeatures: Equatable {
        let trimmedText: String
        let latinCount: Int
        let cjkCount: Int
        let hasLatin: Bool
        let hasCJK: Bool
        let isMixed: Bool
        let hasTranslationStyleEnglish: Bool
        let likelySingleLanguageCollapse: Bool
        let preservedTermCount: Int
    }

    private var whisperKit: WhisperKit?
    private var loadingTask: Task<WhisperKit, Error>?
    private let modelInstaller: WhisperModelInstalling
    var onModelReadinessChange: ((LocalModelReadiness) -> Void)?

    init(modelInstaller: WhisperModelInstalling = WhisperModelInstaller()) {
        self.modelInstaller = modelInstaller
    }
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

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        let pipeline = try await loadPipeline()
        // Loaded once and reused across attempts. The audio is identical every time, so decoding
        // the file again per attempt only repeats work, and holding the samples is what makes
        // trimming the silent tail possible at all.
        let samples = Self.loadSamplesTrimmingTrailingSilence(for: clip)
        var attemptResults: [AttemptResult] = []

        for (index, attempt) in Self.transcriptionAttempts(for: language).enumerated() {
            let options = Self.makeDecodingOptions(for: attempt, tokenizer: pipeline.tokenizer)

            AppLogger.log(
                "WhisperKit: transcribing attempt=\(String(describing: attempt.kind)), " +
                "language=\(attempt.languageCode ?? "auto"), " +
                "prefill=\(options.usePrefillPrompt), detectLanguage=\(options.detectLanguage)"
            )

            let startedAt = Date()
            let results = try await pipeline.transcribe(
                audioArray: samples,
                decodeOptions: options
            )
            let elapsed = Date().timeIntervalSince(startedAt)

            let result = results.first?.text ?? ""
            attemptResults.append(AttemptResult(attempt: attempt, text: result))
            AppLogger.log(
                "WhisperKit: attempt \(String(describing: attempt.kind)) finished in " +
                Self.attemptPerformanceDescription(results, elapsed: elapsed, sampleCount: samples.count)
            )
            AppLogger.log("WhisperKit: attempt \(String(describing: attempt.kind)) raw result: \(result)")

            if Self.canStopAfterAttempt(attempt, text: result, attemptIndex: index, preferredLanguage: language) {
                AppLogger.log(
                    "WhisperKit: attempt \(String(describing: attempt.kind)) is conclusive, " +
                    "skipping \(Self.transcriptionAttempts(for: language).count - index - 1) remaining attempt(s)"
                )
                break
            }

            AppLogger.log("WhisperKit: attempt \(String(describing: attempt.kind)) inconclusive, running next fallback if available")
        }

        if let bestResult = Self.selectBestTranscript(from: attemptResults, preferredLanguage: language),
           !Self.shouldRetryAfterTranscriptionResult(bestResult.text) {
            let cleanedText = TranscriptPostProcessor.clean(
                bestResult.text,
                preferredLanguage: language,
                chineseScriptPreference: chineseScriptPreference
            )
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

    /// WhisperKit re-decodes an entire window at a higher temperature whenever the result trips
    /// `compressionRatioThreshold`, `logProbThreshold`, or `noSpeechThreshold`. Its default of 5
    /// means one bad window can cost six full decodes, and real dictation trips those checks
    /// routinely — the hesitations and restarts in ordinary speech ("好好好", "就是就是") are exactly
    /// what a compression-ratio check reads as a decode loop.
    ///
    /// Two still leaves the escape hatch that matters: temperatures 0.0, 0.2 and 0.4 are tried
    /// before giving up, so a genuinely stuck window can still shake itself loose. What it removes
    /// is the long tail where the fourth, fifth and sixth attempt each cost as much as the first
    /// and rarely change the answer.
    nonisolated static let temperatureFallbackCount = 2

    nonisolated static func makeDecodingOptions(
        for attempt: TranscriptionAttempt,
        tokenizer: WhisperTokenizer? = nil
    ) -> DecodingOptions {
        return DecodingOptions(
            // WhisperKit's verbose path logs every predicted token through `os_log`, which puts the
            // full text of every dictation into the system log where any admin can read it back
            // with `log show`. For an app whose whole claim is that speech never leaves the
            // machine, that is the wrong default.
            verbose: false,
            task: .transcribe,
            language: attempt.languageCode,
            temperatureFallbackCount: temperatureFallbackCount,
            usePrefillPrompt: true,
            detectLanguage: attempt.detectLanguage,
            promptTokens: nil,
            // Only affects clips longer than one 30s window; shorter clips take the single-window
            // path either way. Above that it splits on silence and decodes the pieces
            // concurrently — measured 6.08s to 4.83s on an 85s clip.
            chunkingStrategy: .vad
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

    /// `repeatedFragmentPenalty` scores 40 per adjacent repeat, so this threshold tolerates saying
    /// the same word up to three times in a row and only treats longer runs as a decode loop.
    nonisolated static let loopingHallucinationPenaltyThreshold = 120

    /// Decides whether the attempt that just finished is conclusive enough to skip the remaining
    /// fallbacks. Whisper's dominant failure mode is translating speech into English rather than
    /// transcribing it, so an unexpected English-only result always earns one more attempt while a
    /// result that already matches the requested language does not.
    nonisolated static func canStopAfterAttempt(
        _ attempt: TranscriptionAttempt,
        text: String,
        attemptIndex: Int,
        preferredLanguage: DictationRecognitionLanguage
    ) -> Bool {
        guard !shouldRetryAfterTranscriptionResult(text) else {
            return false
        }

        let features = analyzeTranscript(text, attempt: attempt, preferredLanguage: preferredLanguage)

        // Only a long stutter looks like Whisper's looping hallucination. Saying a word twice or
        // three times ("OK OK", "no no no") is ordinary speech and must not cost extra attempts.
        guard repeatedFragmentPenalty(in: features.trimmedText) < loopingHallucinationPenaltyThreshold else {
            return false
        }

        switch preferredLanguage {
        case .chinese:
            return features.hasCJK && englishDominantPenalty(
                in: features.trimmedText,
                latinCount: features.latinCount,
                cjkCount: features.cjkCount
            ) == 0
        case .english:
            return features.hasLatin && chineseDominantPenalty(
                in: features.trimmedText,
                latinCount: features.latinCount,
                cjkCount: features.cjkCount
            ) == 0
        case .mixed:
            // Code-switched output is exactly what mixed mode asks for.
            if features.isMixed {
                return true
            }

            // Chinese-only output is trustworthy: auto-detect does not translate Chinese into Chinese.
            if features.hasCJK && !features.hasLatin {
                return true
            }

            // English-only output may be a translation of Chinese speech. Let forced-Chinese verify
            // it once; whichever way that comes back, a third attempt adds nothing.
            return attemptIndex >= 1
        }
    }

    nonisolated static func selectBestTranscript(
        from results: [AttemptResult],
        preferredLanguage: DictationRecognitionLanguage
    ) -> AttemptResult? {
        let filteredResults = results.filter { !shouldRetryAfterTranscriptionResult($0.text) }

        guard !filteredResults.isEmpty else {
            return nil
        }

        if preferredLanguage == .mixed {
            return selectBestMixedTranscript(from: filteredResults)
        }

        return filteredResults.max { lhs, rhs in
            transcriptScore(lhs.text, for: preferredLanguage) < transcriptScore(rhs.text, for: preferredLanguage)
        }
    }

    nonisolated static func analyzeTranscript(
        _ text: String,
        attempt: TranscriptionAttempt,
        preferredLanguage: DictationRecognitionLanguage
    ) -> TranscriptFeatures {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalarView = trimmed.unicodeScalars
        let latinCount = scalarView.filter { CharacterSet.letters.contains($0) && $0.value < 128 }.count
        let cjkCount = scalarView.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let hasLatin = latinCount > 0
        let hasCJK = cjkCount > 0
        let isMixed = hasLatin && hasCJK && latinCount >= 4 && cjkCount >= 2
        let lowercase = trimmed.lowercased()
        let translationStylePhrases = [
            "i want to ",
            "can you help me ",
            "let's ",
            "please help me ",
            "i need to "
        ]
        let hasTranslationStyleEnglish =
            !isMixed &&
            !hasCJK &&
            translationStylePhrases.contains(where: { lowercase.contains($0) })

        let preservedTerms = trimmed
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { token in
                let hasASCII = token.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.value < 128 }
                guard hasASCII else { return false }

                let lower = token.lowercased()
                let knownTerms = ["slack", "figma", "notion", "github", "zoom", "amy"]
                let hasInternalCapital = token.dropFirst().contains(where: \.isUppercase)
                let startsUppercase = token.first?.isUppercase == true
                return knownTerms.contains(lower) || hasInternalCapital || startsUppercase
            }

        let likelySingleLanguageCollapse: Bool
        if preferredLanguage == .mixed {
            let substantialEnglish = latinCount >= 12 && cjkCount <= 1
            let substantialChinese = cjkCount >= 8 && latinCount <= 1
            likelySingleLanguageCollapse =
                !isMixed &&
                (hasTranslationStyleEnglish ||
                 attempt.kind == .forcedEnglish && substantialEnglish ||
                 attempt.kind == .forcedChinese && substantialChinese)
        } else {
            likelySingleLanguageCollapse = false
        }

        return TranscriptFeatures(
            trimmedText: trimmed,
            latinCount: latinCount,
            cjkCount: cjkCount,
            hasLatin: hasLatin,
            hasCJK: hasCJK,
            isMixed: isMixed,
            hasTranslationStyleEnglish: hasTranslationStyleEnglish,
            likelySingleLanguageCollapse: likelySingleLanguageCollapse,
            preservedTermCount: preservedTerms.count
        )
    }

    nonisolated static func selectBestMixedTranscript(
        from results: [AttemptResult]
    ) -> AttemptResult? {
        let analyzed = results.map { result in
            (result: result, features: analyzeTranscript(result.text, attempt: result.attempt, preferredLanguage: .mixed))
        }
        let hasMixedCandidate = analyzed.contains { $0.features.isMixed }

        return analyzed.max { lhs, rhs in
            mixedCandidateScore(lhs.features, attempt: lhs.result.attempt, hasMixedCandidate: hasMixedCandidate, text: lhs.result.text) <
                mixedCandidateScore(rhs.features, attempt: rhs.result.attempt, hasMixedCandidate: hasMixedCandidate, text: rhs.result.text)
        }?.result
    }

    nonisolated static func mixedCandidateScore(
        _ features: TranscriptFeatures,
        attempt: TranscriptionAttempt,
        hasMixedCandidate: Bool,
        text: String
    ) -> Int {
        var score = transcriptScore(text, for: .mixed)

        if features.isMixed {
            score += 320
        }

        if features.hasLatin && features.hasCJK && !features.isMixed {
            score -= 260
        }

        if features.hasTranslationStyleEnglish {
            score -= 220
        }

        if features.likelySingleLanguageCollapse {
            score -= hasMixedCandidate ? 520 : 120
        }

        score += features.preservedTermCount * 35

        switch attempt.kind {
        case .autoDetect:
            score += 20
        case .forcedChinese:
            score += features.isMixed ? 10 : 0
        case .forcedEnglish:
            score += 0
        }

        return score
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

    /// Reads the clip as 16 kHz samples and drops the silent tail, falling back to the untrimmed
    /// clip whenever anything is uncertain — a load failure hands the samples straight back to
    /// WhisperKit's own error handling on the next call, and a detector that heard no speech is
    /// not evidence that there was none.
    nonisolated static func loadSamplesTrimmingTrailingSilence(for clip: RecordedAudioClip) -> [Float] {
        let samples: [Float]
        do {
            samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: clip.fileURL.path)
        } catch {
            AppLogger.log("WhisperKit: could not load \(clip.fileURL.lastPathComponent) for trimming: \(error.localizedDescription)")
            return []
        }

        guard samples.isEmpty == false else { return samples }

        let vad = EnergyVAD()
        guard let keptCount = TrailingSilenceTrimmer.trimmedSampleCount(
            voiceActivity: vad.voiceActivity(in: samples),
            totalSamples: samples.count,
            samplesPerFrame: vad.frameLengthSamples,
            sampleRate: WhisperKit.sampleRate
        ) else {
            return samples
        }

        let removedSeconds = Double(samples.count - keptCount) / Double(WhisperKit.sampleRate)
        AppLogger.log(
            "WhisperKit: trimmed \(String(format: "%.2f", removedSeconds))s of trailing silence, " +
            "transcribing \(String(format: "%.2f", Double(keptCount) / Double(WhisperKit.sampleRate)))s"
        )
        return Array(samples.prefix(keptCount))
    }

    /// Turns one attempt into a line the debug log can be read for timings, so a slow dictation can
    /// be attributed to decode length or to temperature fallbacks without attaching a profiler.
    nonisolated static func attemptPerformanceDescription(
        _ results: [TranscriptionResult],
        elapsed: TimeInterval,
        sampleCount: Int
    ) -> String {
        let audioSeconds = Double(sampleCount) / Double(WhisperKit.sampleRate)
        let realTimeFactor = audioSeconds > 0 ? elapsed / audioSeconds : 0
        let segments = results.flatMap(\.segments)
        let tokenCount = segments.reduce(0) { $0 + $1.tokens.count }
        let highestTemperature = segments.map(\.temperature).max() ?? 0
        let highestCompressionRatio = segments.map(\.compressionRatio).max() ?? 0

        // Anything above the starting temperature means at least one window was decoded more than
        // once, which is the difference between a slow clip and a slow model.
        let fallbackNote = highestTemperature > 0
            ? ", temperature fallback fired (max temp \(String(format: "%.1f", highestTemperature)))"
            : ""

        return "\(String(format: "%.2f", elapsed))s for \(String(format: "%.2f", audioSeconds))s of audio " +
            "(rtf \(String(format: "%.3f", realTimeFactor)), \(tokenCount) tokens, " +
            "max compression ratio \(String(format: "%.2f", highestCompressionRatio)))\(fallbackNote)"
    }

    func prewarm() async {
        do {
            _ = try await loadPipeline()
        } catch {
            // The next real dictation retries and reports the failure through the normal path.
            AppLogger.log("WhisperKit: prewarm failed, model will load on first dictation instead: \(error)")
        }
    }

    private func loadPipeline() async throws -> WhisperKit {
        if let whisperKit {
            onModelReadinessChange?(.ready)
            return whisperKit
        }

        // A dictation started while prewarming is still running must join that load, not start
        // a second copy of a multi-gigabyte model.
        if let loadingTask {
            AppLogger.log("WhisperKit: joining in-flight model load")
            onModelReadinessChange?(.preparing)
            do {
                return try await loadingTask.value
            } catch {
                onModelReadinessChange?(.failed(Self.modelReadinessFailureMessage(for: error)))
                throw error
            }
        }

        onModelReadinessChange?(.preparing)

        // A missing model is recoverable: the lightweight build ships without one on purpose, so
        // offer to fetch it rather than dead-ending on an error the user cannot act on.
        if LocalWhisperPaths.modelFolderExists == false {
            AppLogger.log("WhisperKit: no model found in \(LocalWhisperPaths.searchedModelFolders.count) searched location(s)")
            do {
                guard try await modelInstaller.installIfNeeded(progress: { [weak self] message in
                    self?.onModelReadinessChange?(.preparing)
                    AppLogger.log("WhisperKit: \(message)")
                }) != nil else {
                    let declined = "The speech model is not installed. Choose Try Again to download it."
                    onModelReadinessChange?(.failed(declined))
                    throw TranscriptionError.modelUnavailable(declined)
                }
            } catch let error as TranscriptionError {
                throw error
            } catch {
                let message = "Could not download the speech model: \(error.localizedDescription)"
                AppLogger.log("WhisperKit: \(message)")
                onModelReadinessChange?(.failed(message))
                throw TranscriptionError.modelUnavailable(message)
            }
        }

        if let validationError = LocalWhisperPaths.validationError() {
            AppLogger.log("WhisperKit: model validation failed: \(validationError)")
            onModelReadinessChange?(.failed(validationError))
            throw TranscriptionError.modelUnavailable(validationError)
        }

        AppLogger.log(
            "WhisperKit: loading validated local model \(LocalWhisperPaths.expectedModelIdentifier) from \(LocalWhisperPaths.modelFolder)"
        )
        if !LocalWhisperPaths.hasContextPrefill {
            AppLogger.log(
                "WhisperKit: TextDecoderContextPrefill is missing, prefill tokens will be decoded one by one"
            )
        }
        // `verbose` gates WhisperKit's whole logging path, including the per-token line in the
        // decode loop. Keeping it off leaves the app's own `AppLogger` as the single place
        // dictation is recorded, which is both quieter and the only one that does not write
        // transcript text into the system log.
        let config = WhisperKitConfig(
            modelFolder: LocalWhisperPaths.modelFolder,
            tokenizerFolder: LocalWhisperPaths.tokenizerBaseFolder,
            verbose: false,
            logLevel: .error,
            load: true,
            download: false
        )

        let task = Task { try await WhisperKit(config) }
        loadingTask = task
        defer { loadingTask = nil }

        do {
            let pipeline = try await task.value
            whisperKit = pipeline
            onModelReadinessChange?(.ready)
            AppLogger.log("WhisperKit: pipeline loaded successfully")
            return pipeline
        } catch {
            onModelReadinessChange?(.failed(Self.modelReadinessFailureMessage(for: error)))
            throw error
        }
    }

    private nonisolated static func modelReadinessFailureMessage(for error: Error) -> String {
        switch error {
        case TranscriptionError.engineUnavailable:
            "WhisperKit is unavailable."
        case let TranscriptionError.modelUnavailable(message), let TranscriptionError.failed(message):
            message
        default:
            error.localizedDescription
        }
    }
}
