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
    func mixedTranscriptSelectionPrefersFaithfulMixedOutputOverSmoothEnglishRewrite() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "I want to schedule a meeting with Amy tomorrow"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "我明天想 schedule 一个 meeting 给 Amy"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "schedule meeting Amy tomorrow"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "我明天想 schedule 一个 meeting 给 Amy")
    }

    @Test
    func mixedTranscriptSelectionKeepsEnglishLedCodeSwitching() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "Can you 帮我 ping 一下 Amy about the launch"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "你可以帮我联系 Amy 关于发布"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "Can you help me ping Amy about the launch"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "Can you 帮我 ping 一下 Amy about the launch")
    }

    @Test
    func transcriptAnalysisDetectsTranslationStyleEnglishPattern() {
        let features = WhisperKitTranscriptionEngine.analyzeTranscript(
            "I want to schedule a meeting tomorrow",
            attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
            preferredLanguage: .mixed
        )

        #expect(features.hasTranslationStyleEnglish == true)
        #expect(features.isMixed == false)
    }

    @Test
    func mixedTranscriptSelectionAllowsPureChineseWhenSpeechIsActuallyChinese() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "我明天想开会"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "我明天想开会"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "I want to have a meeting tomorrow"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "我明天想开会")
    }

    @Test
    func mixedTranscriptSelectionAllowsPureEnglishWhenSpeechIsActuallyEnglish() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "Can you send Amy the update tomorrow"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "你可以明天把更新发给 Amy 吗"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "Can you send Amy the update tomorrow"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "Can you send Amy the update tomorrow")
    }

    @Test
    func mixedTranscriptSelectionPrefersCandidateThatPreservesProductTerms() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "我想在 Slack 发个 message 给 Amy about the Figma file"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "我想给 Amy 发消息关于那个设计文件"
                ),
                .init(
                    attempt: .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
                    text: "I want to send Amy a message about the design file"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "我想在 Slack 发个 message 给 Amy about the Figma file")
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
    func transcriptPostProcessorRemovesTrailingThankYouHallucination() {
        let cleaned = TranscriptPostProcessor.clean(
            "我們明天再同步一次進度 Thank you",
            preferredLanguage: .mixed
        )

        #expect(cleaned == "我們明天再同步一次進度")
    }

    @Test
    func transcriptPostProcessorPreservesStandaloneThankYou() {
        let cleaned = TranscriptPostProcessor.clean(
            "Thank you",
            preferredLanguage: .english
        )

        #expect(cleaned == "Thank you")
    }

    @Test
    func transcriptPostProcessorCanConvertToTraditionalChinese() {
        let cleaned = TranscriptPostProcessor.clean(
            "后台开发要先发给Amy确认",
            preferredLanguage: .chinese,
            chineseScriptPreference: .traditional
        )

        #expect(cleaned == "後台開發要先發給Amy確認")
    }

    @Test
    func transcriptPostProcessorCanConvertToSimplifiedChinese() {
        let cleaned = TranscriptPostProcessor.clean(
            "後台開發要先發給Amy確認",
            preferredLanguage: .mixed,
            chineseScriptPreference: .simplified
        )

        #expect(cleaned == "后台开发要先发给Amy确认")
    }

    @Test
    func localWhisperPathValidationRequiresLargeV3Model() {
        #expect(LocalWhisperPaths.validationError() == nil)
        #expect(LocalWhisperPaths.modelFolder.contains(LocalWhisperPaths.expectedModelIdentifier))
    }
}
