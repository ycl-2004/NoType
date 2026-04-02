# Auto Mixed Transcription Fidelity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Auto` preserve spoken Chinese-English code-switching instead of choosing smoother single-language rewrites.

**Architecture:** Keep the existing three-attempt WhisperKit fallback flow and add a small mixed-mode fidelity analysis layer inside `WhisperKitTranscriptionEngine`. Route `.mixed` candidate selection through a dedicated selector that rewards preserved mixed-language evidence and penalizes single-language collapse, while keeping `.chinese` and `.english` behavior stable.

**Tech Stack:** Swift, Swift Testing, WhisperKit

---

## File Map

- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
  Responsibility: add transcript feature analysis helpers and mixed-specific candidate selection.
- Modify: `Tests/TypelessTests/TranscriptionEngineTests.swift`
  Responsibility: add focused regression tests for mixed-language fidelity and selection behavior.

### Task 1: Add failing mixed-fidelity regression tests

**Files:**
- Modify: `Tests/TypelessTests/TranscriptionEngineTests.swift`
- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift` if test scaffolding needs new helper visibility

- [ ] **Step 1: Write the failing test for English rewrite losing to faithful mixed output**

```swift
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
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter mixedTranscriptSelectionPrefersFaithfulMixedOutputOverSmoothEnglishRewrite`
Expected: FAIL because current mixed selection can still favor the smoother all-English result.

- [ ] **Step 3: Write the failing test for English-led mixed speech staying mixed**

```swift
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
```

- [ ] **Step 4: Run the focused test to verify it fails**

Run: `swift test --filter mixedTranscriptSelectionKeepsEnglishLedCodeSwitching`
Expected: FAIL before the mixed-specific selector exists.

- [ ] **Step 5: Commit the test-only change**

```bash
git add Tests/TypelessTests/TranscriptionEngineTests.swift
git commit -m "test: add mixed transcription fidelity regressions"
```

### Task 2: Add transcript feature analysis helpers

**Files:**
- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Test: `Tests/TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Add a small analysis type for transcript features**

```swift
struct TranscriptFeatures: Equatable {
    let trimmedText: String
    let latinCount: Int
    let cjkCount: Int
    let hasLatin: Bool
    let hasCJK: Bool
    let isMixed: Bool
    let hasTranslationStyleEnglish: Bool
    let likelySingleLanguageCollapse: Bool
}
```

- [ ] **Step 2: Add a deterministic analyzer helper**

```swift
nonisolated static func analyzeTranscript(
    _ text: String,
    attempt: TranscriptionAttempt,
    preferredLanguage: DictationRecognitionLanguage
) -> TranscriptFeatures {
    // compute counts and mixed/collapse heuristics here
}
```

- [ ] **Step 3: Add a focused unit test for translation-style detection**

```swift
@Test
func transcriptAnalysisDetectsTranslationStyleEnglishPattern() {
    let features = WhisperKitTranscriptionEngine.analyzeTranscript(
        "I want to schedule a meeting tomorrow",
        attempt: .init(kind: .autoDetect, languageCode: nil, detectLanguage: true),
        preferredLanguage: .mixed
    )

    #expect(features.hasTranslationStyleEnglish == true)
}
```

- [ ] **Step 4: Run the focused analyzer test**

Run: `swift test --filter transcriptAnalysisDetectsTranslationStyleEnglishPattern`
Expected: PASS after the helper is implemented.

- [ ] **Step 5: Commit the helper layer**

```bash
git add Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift Tests/TypelessTests/TranscriptionEngineTests.swift
git commit -m "feat: add mixed transcript feature analysis"
```

### Task 3: Route mixed selection through a fidelity-first selector

**Files:**
- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Test: `Tests/TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Add a mixed-only selection helper**

```swift
nonisolated static func selectBestMixedTranscript(
    from results: [AttemptResult]
) -> AttemptResult? {
    // compare candidates by mixed evidence, translation penalty, and general quality
}
```

- [ ] **Step 2: Update `selectBestTranscript` to branch on `.mixed`**

```swift
if preferredLanguage == .mixed {
    return selectBestMixedTranscript(from: filteredResults)
}
```

- [ ] **Step 3: Add a regression test that pure Chinese still stays valid in `Auto`**

```swift
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
```

- [ ] **Step 4: Add a regression test that pure English still stays valid in `Auto`**

```swift
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
```

- [ ] **Step 5: Run the mixed-selection test slice**

Run: `swift test --filter mixedTranscriptSelection`
Expected: PASS for the new mixed-specific selection behavior, with existing Chinese-mode regressions still green.

- [ ] **Step 6: Commit the selector change**

```bash
git add Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift Tests/TypelessTests/TranscriptionEngineTests.swift
git commit -m "feat: prefer faithful mixed transcripts in auto mode"
```

### Task 4: Add preservation tests for names and product terms

**Files:**
- Modify: `Tests/TypelessTests/TranscriptionEngineTests.swift`
- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift` if helper thresholds need tuning

- [ ] **Step 1: Add a regression test for product-name preservation**

```swift
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
```

- [ ] **Step 2: Run the focused preservation test**

Run: `swift test --filter mixedTranscriptSelectionPrefersCandidateThatPreservesProductTerms`
Expected: PASS after term-preservation heuristics are wired into mixed selection.

- [ ] **Step 3: Run the full transcription test suite**

Run: `swift test --filter TranscriptionEngineTests`
Expected: PASS with old and new transcription engine tests all green.

- [ ] **Step 4: Commit the preservation coverage**

```bash
git add Tests/TypelessTests/TranscriptionEngineTests.swift Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift
git commit -m "test: cover mixed transcription term preservation"
```

### Task 5: Final verification and handoff

**Files:**
- Review: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Review: `Tests/TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Run the complete package test suite**

Run: `swift test`
Expected: PASS for the full package.

- [ ] **Step 2: Inspect the diff for accidental scope growth**

Run: `git diff --stat main...HEAD`
Expected: only the transcription engine and its tests changed for phase one.

- [ ] **Step 3: Summarize user-visible behavior changes**

Capture these outcomes:

- `Auto` now prefers faithful mixed-language transcripts
- smooth single-language rewrites lose when a mixed candidate better matches the spoken content
- pure Chinese and pure English still work in `Auto`
- prompt tokens remain disabled in this phase

- [ ] **Step 4: Commit the final verification pass**

```bash
git add Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift Tests/TypelessTests/TranscriptionEngineTests.swift
git commit -m "chore: verify mixed auto transcription fidelity changes"
```
