import Testing
@testable import Typeless

struct TranscriptionEngineTests {
    @Test
    func transcriptResultPreservesRecognizedText() {
        let result = TranscriptResult(text: "Hello 你好")

        #expect(result.text == "Hello 你好")
        #expect(result.rawText == "Hello 你好")
    }

    @Test
    func mixedRecognitionDoesNotForceSingleLanguagePrompt() {
        let options = WhisperKitTranscriptionEngine.makeDecodingOptions(for: .mixed)

        #expect(options.language == nil)
        #expect(options.usePrefillPrompt == true)
        #expect(options.detectLanguage == true)
    }

    @Test
    func fixedLanguageRecognitionUsesForcedLanguagePrompt() {
        let options = WhisperKitTranscriptionEngine.makeDecodingOptions(for: .chinese)

        #expect(options.language == "zh")
        #expect(options.usePrefillPrompt == true)
        #expect(options.detectLanguage == false)
    }

    @Test
    func transcriptResultCanPreserveRawTranscript() {
        let result = TranscriptResult(text: "开会 tomorrow", rawText: "嗯 开会 tomorrow")

        #expect(result.text == "开会 tomorrow")
        #expect(result.rawText == "嗯 开会 tomorrow")
    }

    @Test
    func mixedRecognitionPromptMentionsNoTranslationAndCodeSwitching() {
        let prompt = WhisperKitTranscriptionEngine.mixedPromptText

        #expect(prompt.contains("Do not translate"))
        #expect(prompt.contains("Chinese and English may appear in the same sentence"))
        #expect(prompt.contains("不要翻译"))
        #expect(prompt.contains("同一句里可能同时出现中文和英文"))
    }

    @Test
    func mixedRecognitionUsesAutoChineseEnglishAttemptOrder() {
        let attempts = WhisperKitTranscriptionEngine.transcriptionAttempts(for: .mixed)

        #expect(attempts.map(\.kind) == [.autoDetect, .forcedChinese, .forcedEnglish])
    }

    @Test
    func fixedLanguageRecognitionUsesPreferredFallbackAttemptOrder() {
        let chineseAttempts = WhisperKitTranscriptionEngine.transcriptionAttempts(for: .chinese)
        let englishAttempts = WhisperKitTranscriptionEngine.transcriptionAttempts(for: .english)

        #expect(chineseAttempts.map(\.kind) == [.forcedChinese, .autoDetect, .forcedEnglish])
        #expect(englishAttempts.map(\.kind) == [.forcedEnglish, .autoDetect, .forcedChinese])
    }

    @Test
    func mixedAutoRecognitionUsesLanguageDetectionWithoutPromptTokens() throws {
        let attempt = try #require(WhisperKitTranscriptionEngine.transcriptionAttempts(for: .mixed).first)
        let options = WhisperKitTranscriptionEngine.makeDecodingOptions(for: attempt)

        #expect(options.language == nil)
        #expect(options.usePrefillPrompt == true)
        #expect(options.detectLanguage == true)
        #expect(options.promptTokens == nil)
    }

    @Test
    func fixedLanguagePromptMentionsMixedTermsWithoutTranslation() {
        let chinesePrompt = WhisperKitTranscriptionEngine.promptText(
            for: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false)
        )
        let englishPrompt = WhisperKitTranscriptionEngine.promptText(
            for: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false)
        )

        #expect(chinesePrompt.contains("technical terms"))
        #expect(chinesePrompt.contains("不要翻译"))
        #expect(englishPrompt.contains("Chinese words"))
        #expect(englishPrompt.contains("Do not translate"))
    }

    @Test
    func fixedLanguageRecognitionCurrentlyLeavesPromptTokensDisabled() {
        let chineseOptions = WhisperKitTranscriptionEngine.makeDecodingOptions(for: .chinese)
        let englishOptions = WhisperKitTranscriptionEngine.makeDecodingOptions(for: .english)

        #expect(chineseOptions.promptTokens == nil)
        #expect(englishOptions.promptTokens == nil)
    }

    @Test
    func whitespaceOnlyTranscriptTriggersRetryOnlyForAutoMode() {
        #expect(WhisperKitTranscriptionEngine.shouldRetryAfterTranscriptionResult("   \n\t") == true)
        #expect(WhisperKitTranscriptionEngine.shouldRetryAfterTranscriptionResult("") == true)
        #expect(WhisperKitTranscriptionEngine.shouldRetryAfterTranscriptionResult("Hello 你好") == false)
    }

    @Test
    func mixedTranscriptScoringPrefersCodeSwitchedText() {
        let mixedScore = WhisperKitTranscriptionEngine.transcriptScore(
            "我想 schedule 一个 meeting tomorrow",
            for: .mixed
        )
        let chineseScore = WhisperKitTranscriptionEngine.transcriptScore("我想明天开会", for: .mixed)
        let englishScore = WhisperKitTranscriptionEngine.transcriptScore("I want a meeting tomorrow", for: .mixed)

        #expect(mixedScore > chineseScore)
        #expect(mixedScore > englishScore)
    }

    @Test
    func mixedTranscriptSelectionChoosesBestScoredCandidate() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true), text: "I want a meeting tomorrow"),
                .init(attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false), text: "我想 schedule 一个 meeting tomorrow"),
                .init(attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false), text: "I want schedule meeting")
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "我想 schedule 一个 meeting tomorrow")
    }

    @Test
    func chineseTranscriptSelectionKeepsCodeSwitchedChineseLead() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false), text: "我想在 Slack 发一个 message 给 Amy"),
                .init(attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true), text: "I want to send a message to Amy on Slack"),
                .init(attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false), text: "send message Slack Amy")
            ],
            preferredLanguage: .chinese
        )

        #expect(selected?.text == "我想在 Slack 发一个 message 给 Amy")
    }

    @Test
    func chineseFirstModeRejectsEnglishTranslationWhenChineseCandidateExists() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "我想在slack發一個message給Amy說我想跟她在一起然後也跟張玉潔說"
                ),
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "我想在slack發一個message給Amy說我想跟她在一起然後也跟張玉潔說"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "I want to send a message to Amy in Slack I want to share with her together And also with Zhang Yue杰"
                )
            ],
            preferredLanguage: .chinese
        )

        #expect(selected?.attempt.kind != .forcedEnglish)
        #expect(selected?.text == "我想在slack發一個message給Amy說我想跟她在一起然後也跟張玉潔說")
    }

    @Test
    func transcriptPostProcessorRemovesStandaloneFillers() {
        let cleaned = TranscriptPostProcessor.clean(
            "嗯 我想在 Slack 发一个 message 给 Amy you know",
            preferredLanguage: .chinese
        )

        #expect(cleaned == "我想在 Slack 发一个 message 给 Amy")
    }

    @Test
    func transcriptPostProcessorKeepsMeaningfulMixedContent() {
        let cleaned = TranscriptPostProcessor.clean(
            "然后 我们明天 sync 一下 roadmap",
            preferredLanguage: .mixed
        )

        #expect(cleaned == "我们明天 sync 一下 roadmap")
    }

    @Test
    func localWhisperPathValidationRequiresLargeV3Model() {
        #expect(LocalWhisperPaths.validationError() == nil)
        #expect(LocalWhisperPaths.modelFolder.contains(LocalWhisperPaths.expectedModelIdentifier))
    }
}
