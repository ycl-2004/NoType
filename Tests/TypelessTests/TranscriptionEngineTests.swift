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
    func transcriptResultCanPreserveRawTranscript() {
        let result = TranscriptResult(text: "开会 tomorrow", rawText: "嗯 开会 tomorrow")

        #expect(result.text == "开会 tomorrow")
        #expect(result.rawText == "嗯 开会 tomorrow")
    }

    @Test
    func audioEnergyVADDetectsSpeechFrames() {
        let vad = AudioEnergyVAD()
        let silence = [Float](repeating: 0, count: vad.frameLengthSamples)
        let speech = [Float](repeating: 0.1, count: vad.frameLengthSamples)

        #expect(vad.voiceActivity(in: silence + speech) == [false, true])
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
        let spoken = "他会自动帮我写入一个谢谢大家就这四个字你帮我看一下这是为什么"

        #expect(TranscriptPostProcessor.clean(spoken, preferredLanguage: .chinese) == spoken)
    }

    @Test
    func transcriptPostProcessorPreservesStandaloneSignOff() {
        #expect(TranscriptPostProcessor.clean("谢谢大家", preferredLanguage: .chinese) == "谢谢大家")
    }

    @Test
    func transcriptPostProcessorPreservesStandaloneThankYou() {
        #expect(TranscriptPostProcessor.clean("Thank you", preferredLanguage: .english) == "Thank you")
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
}

struct ChineseSpacingTests {
    @Test
    func chunkBoundarySpacesBetweenHanCharactersAreRemoved() {
        let cleaned = TranscriptPostProcessor.clean(
            "我们用的是本地的麦克风输入 采样率是16000赫兹",
            preferredLanguage: .chinese,
            chineseScriptPreference: .simplified
        )

        #expect(cleaned == "我们用的是本地的麦克风输入采样率是16000赫兹")
    }

    @Test
    func spacesAroundLatinTextInMixedSentencesSurvive() {
        let cleaned = TranscriptPostProcessor.clean(
            "等下我们用 GitHub Action 跑一遍 CI",
            preferredLanguage: .mixed,
            chineseScriptPreference: .followModel
        )

        #expect(cleaned == "等下我们用 GitHub Action 跑一遍 CI")
    }

    @Test
    func spaceAfterFullWidthPunctuationIsRemoved() {
        let cleaned = TranscriptPostProcessor.clean(
            "回到这个app里面来使用。 或者是怎么样的， 用 GitHub 跑一遍。 GitHub 很好",
            preferredLanguage: .mixed,
            chineseScriptPreference: .followModel
        )

        #expect(cleaned == "回到这个app里面来使用。或者是怎么样的，用 GitHub 跑一遍。GitHub 很好")
    }

    @Test
    func droppedFillerDoesNotLeaveDoublePunctuation() {
        // Observed in a real dictation: "很多，然后。 只是" was inserted as "很多，。 只是".
        let cleaned = TranscriptPostProcessor.clean(
            "我其实用它用的很多，然后。 只是最近变慢了，，然后，我才想回来",
            preferredLanguage: .mixed,
            chineseScriptPreference: .followModel
        )

        #expect(cleaned == "我其实用它用的很多。只是最近变慢了，我才想回来")
    }

    @Test
    func spacesBetweenHanAndDigitsAreLeftAlone() {
        let cleaned = TranscriptPostProcessor.clean(
            "采样率是 16000 赫兹",
            preferredLanguage: .chinese,
            chineseScriptPreference: .simplified
        )

        #expect(cleaned == "采样率是 16000 赫兹")
    }
}
