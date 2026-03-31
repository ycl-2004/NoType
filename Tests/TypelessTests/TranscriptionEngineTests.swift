import Testing
@testable import Typeless

struct TranscriptionEngineTests {
    @Test
    func transcriptResultPreservesRecognizedText() {
        let result = TranscriptResult(text: "Hello 你好")

        #expect(result.text == "Hello 你好")
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
    func fixedLanguageRecognitionUsesSingleAttempt() {
        let chineseAttempts = WhisperKitTranscriptionEngine.transcriptionAttempts(for: .chinese)
        let englishAttempts = WhisperKitTranscriptionEngine.transcriptionAttempts(for: .english)

        #expect(chineseAttempts.map(\.kind) == [.forcedChinese])
        #expect(englishAttempts.map(\.kind) == [.forcedEnglish])
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
}
