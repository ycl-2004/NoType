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
    func chineseModeStopsAfterFirstForcedChineseAttempt() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
            text: "我想在slack發一個message給Amy說我想跟她在一起然後也跟張玉潔說",
            attemptIndex: 0,
            preferredLanguage: .chinese
        )

        #expect(stop == true)
    }

    @Test
    func chineseModeKeepsGoingWhenForcedChineseReturnsEnglishTranslation() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
            text: "I want to send a message to Amy in Slack and share the update with her",
            attemptIndex: 0,
            preferredLanguage: .chinese
        )

        #expect(stop == false)
    }

    @Test
    func englishModeStopsAfterFirstForcedEnglishAttempt() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
            text: "Can you send Amy the update tomorrow",
            attemptIndex: 0,
            preferredLanguage: .english
        )

        #expect(stop == true)
    }

    @Test
    func englishModeKeepsGoingWhenForcedEnglishReturnsChineseTranslation() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
            text: "你可以明天把更新發給她並且順便同步一下進度嗎",
            attemptIndex: 0,
            preferredLanguage: .english
        )

        #expect(stop == false)
    }

    @Test
    func mixedModeStopsImmediatelyOnCodeSwitchedAutoDetectResult() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
            text: "我想在 Slack 发个 message 给 Amy about the Figma file",
            attemptIndex: 0,
            preferredLanguage: .mixed
        )

        #expect(stop == true)
    }

    @Test
    func mixedModeStopsImmediatelyOnChineseOnlyAutoDetectResult() {
        let stop = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
            text: "我明天想開會然後跟團隊同步一下進度",
            attemptIndex: 0,
            preferredLanguage: .mixed
        )

        #expect(stop == true)
    }

    @Test
    func mixedModeVerifiesEnglishOnlyAutoDetectResultExactlyOnce() {
        let englishOnly = "Can you send Amy the update tomorrow"

        let stopAfterAutoDetect = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
            text: englishOnly,
            attemptIndex: 0,
            preferredLanguage: .mixed
        )
        let stopAfterForcedChinese = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
            text: "你可以明天把更新发给 Amy 吗",
            attemptIndex: 1,
            preferredLanguage: .mixed
        )

        #expect(stopAfterAutoDetect == false)
        #expect(stopAfterForcedChinese == true)
    }

    @Test
    func conversationalWordRepetitionStillStopsTheAttemptChain() {
        // Observed in a real dictation: saying "OK OK" was treated as a decode loop and cost two
        // extra attempts even though the transcript was already correct.
        let repeatedTwice = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
            text: "OK OK 现在好吗",
            attemptIndex: 0,
            preferredLanguage: .chinese
        )
        let repeatedThreeTimes = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
            text: "no no no we ship tomorrow",
            attemptIndex: 0,
            preferredLanguage: .english
        )

        #expect(repeatedTwice == true)
        #expect(repeatedThreeTimes == true)
    }

    @Test
    func emptyOrLoopingResultNeverStopsTheAttemptChain() {
        let empty = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
            text: "   \n\t",
            attemptIndex: 0,
            preferredLanguage: .chinese
        )
        let looping = WhisperKitTranscriptionEngine.canStopAfterAttempt(
            .init(kind: .forcedEnglish, languageCode: "en", detectLanguage: false),
            text: "so so so so so we ship tomorrow",
            attemptIndex: 0,
            preferredLanguage: .english
        )

        #expect(empty == false)
        #expect(looping == false)
    }

    @Test
    func mixedModeVerificationPathStillSelectsTheFaithfulCandidate() {
        // Only two attempts run once auto-detect returns English-only, so selection must reach the
        // same verdict it previously reached with all three candidates present.
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "Can you send Amy the update tomorrow"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "你可以明天把更新发给 Amy 吗"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "Can you send Amy the update tomorrow")
    }

    @Test
    func mixedModeVerificationPathRecoversTranslatedChineseSpeech() {
        let selected = WhisperKitTranscriptionEngine.selectBestTranscript(
            from: [
                .init(
                    attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
                    text: "I want to schedule a meeting with Amy tomorrow"
                ),
                .init(
                    attempt: .init(kind: .forcedChinese, languageCode: "zh", detectLanguage: false),
                    text: "我明天想 schedule 一个 meeting 给 Amy"
                )
            ],
            preferredLanguage: .mixed
        )

        #expect(selected?.text == "我明天想 schedule 一个 meeting 给 Amy")
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
    func transcriptPostProcessorKeepsLikeYouKnowAndIMeanAsRealWords() {
        // "I like it" used to come out as "I it".
        #expect(TranscriptPostProcessor.clean("I like it", preferredLanguage: .english) == "I like it")
        #expect(
            TranscriptPostProcessor.clean("I really like this design", preferredLanguage: .english)
                == "I really like this design"
        )
        #expect(
            TranscriptPostProcessor.clean("you know the answer", preferredLanguage: .english)
                == "you know the answer"
        )
        #expect(TranscriptPostProcessor.clean("I mean it", preferredLanguage: .english) == "I mean it")
        #expect(
            TranscriptPostProcessor.clean("this looks like a bug", preferredLanguage: .english)
                == "this looks like a bug"
        )
    }

    @Test
    func transcriptPostProcessorKeepsTrailingLikeButDropsTrailingYouKnow() {
        #expect(
            TranscriptPostProcessor.clean("what's it like", preferredLanguage: .english)
                == "what's it like"
        )
        #expect(
            TranscriptPostProcessor.clean("it went well you know", preferredLanguage: .english)
                == "it went well"
        )
    }

    @Test
    func transcriptPostProcessorRemovesFillersThatArePausedOnBothSides() {
        #expect(
            TranscriptPostProcessor.clean("I was, like, really tired", preferredLanguage: .english)
                == "I was, really tired"
        )
        #expect(
            TranscriptPostProcessor.clean("we should, you know, ship it", preferredLanguage: .english)
                == "we should, ship it"
        )
    }

    @Test
    func transcriptPostProcessorStillRemovesMeaninglessDisfluencies() {
        #expect(TranscriptPostProcessor.clean("um I think so", preferredLanguage: .english) == "I think so")
        #expect(TranscriptPostProcessor.clean("uh yes", preferredLanguage: .english) == "yes")
        #expect(
            TranscriptPostProcessor.clean("嗯 我想在 Slack 发个 message", preferredLanguage: .mixed)
                == "我想在 Slack 发个 message"
        )
    }

    @Test
    func transcriptPostProcessorLeavesConnectedChineseSpeechUntouched() {
        let spoken = "你先帮我看一下就是我们现在语音输入的话就是我们可能讲一句话然后它传给模型"

        #expect(TranscriptPostProcessor.clean(spoken, preferredLanguage: .mixed) == spoken)
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
    func transcriptPostProcessorRemovesSubtitleSignOffHallucination() {
        // All three shapes were captured from real dictation logs.
        #expect(
            TranscriptPostProcessor.clean(
                "然后确保所有东西都说有办法好理解的这样子越完整越细节越好谢谢大家",
                preferredLanguage: .chinese
            ) == "然后确保所有东西都说有办法好理解的这样子越完整越细节越好"
        )
        #expect(
            TranscriptPostProcessor.clean(
                "你也幫我把我們的Harness換成我們想要的顏色的風格這樣子谢谢大家",
                preferredLanguage: .chinese
            ) == "你也幫我把我們的Harness換成我們想要的顏色的風格這樣子"
        )
        #expect(
            TranscriptPostProcessor.clean("我们明天再同步一次进度 谢谢观看", preferredLanguage: .chinese)
                == "我们明天再同步一次进度"
        )
        #expect(
            TranscriptPostProcessor.clean(
                "这个功能已经做完了 请不吝点赞 订阅 转发 打赏",
                preferredLanguage: .chinese
            ) == "这个功能已经做完了"
        )
    }

    @Test
    func transcriptPostProcessorKeepsSignOffWordsThatAreNotAtTheEnd() {
        // Spoken while reporting the bug itself: the phrase is quoted mid-sentence and must survive.
        let spoken = "他会自动帮我写入一个谢谢大家就这四个字你帮我看一下这是为什么"

        #expect(TranscriptPostProcessor.clean(spoken, preferredLanguage: .chinese) == spoken)
    }

    @Test
    func transcriptPostProcessorPreservesStandaloneSignOff() {
        // Nothing but the hallucination means there is no real speech to keep; deleting it would
        // silently produce an empty transcript, so it is left for the user to discard.
        #expect(TranscriptPostProcessor.clean("谢谢大家", preferredLanguage: .chinese) == "谢谢大家")
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
