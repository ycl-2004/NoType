# Auto Mixed Transcription Fidelity Design

**Date:** 2026-03-31
**Status:** Approved in brainstorming
**Goal:** Make `Auto` prefer faithful mixed Chinese-English transcription over smoother single-language rewrites.

## Problem

The current `mixed` mode in `WhisperKitTranscriptionEngine` runs three attempts:

1. `autoDetect`
2. `forcedChinese`
3. `forcedEnglish`

It then selects a winner mostly from text-shape scoring. This improves fallback resilience, but it still allows a structurally wrong result:

- the user speaks in mixed Chinese and English
- one candidate preserves the mixed-language wording with some noise
- another candidate is a smoother all-English sentence
- the smoother English sentence can win

That behavior conflicts with the intended `Auto` user experience. In `Auto`, the app should transcribe what was spoken, not translate, normalize, or collapse mixed speech into a single language.

## Success Criteria

`Auto` should follow these rules:

- preserve code-switching when the user actually spoke in mixed Chinese and English
- prefer a slightly noisier mixed-language transcript over a smoother single-language rewrite
- never intentionally translate mixed speech into all-English or all-Chinese output
- still allow pure Chinese output when the speech is actually pure Chinese
- still allow pure English output when the speech is actually pure English

## Recommended Approach

Use a mixed-specific fidelity decision layer on top of the existing three-attempt fallback flow.

Keep the current attempt order:

1. `autoDetect`
2. `forcedChinese`
3. `forcedEnglish`

Do not replace the pipeline structure in phase one. Instead, change how mixed candidates are evaluated and selected.

### Why this approach

This is the best balance of accuracy, scope, and risk:

- smaller than segment-level redesign
- more reliable than simply tweaking the current score constants
- aligned with the user goal of preserving spoken language rather than rewarding sentence fluency

## Design

### 1. Add candidate feature analysis

For each candidate transcript, extract lightweight fidelity signals such as:

- count of CJK characters
- count of Latin letters
- whether both language families appear
- whether the result looks like mixed-language speech or single-language collapse
- whether the result contains likely translation-style English phrasing
- whether product names, proper nouns, or technical terms are preserved

This analysis should stay local to the transcription engine and remain deterministic and testable.

### 2. Add a mixed-specific selector

When `preferredLanguage == .mixed`, selection should no longer rely on the current generic text score alone.

The selector should prefer, in order:

1. candidates that preserve mixed-language evidence
2. candidates that avoid obvious translation-style rewrites
3. candidates that preserve names, product terms, and technical words
4. candidates with better general quality among the remaining options

This changes the optimization target from "most fluent sentence" to "most faithful transcript."

### 3. Penalize single-language collapse in mixed mode

In `mixed` mode, pure English or pure Chinese output is not always wrong. It becomes suspicious when:

- another candidate clearly preserves mixed-language wording
- the single-language candidate reads like a rewritten sentence rather than a transcript

The selector should apply a strong penalty in that situation so that `forcedEnglish` or `forcedChinese` cannot win only because they sound smoother.

### 4. Keep fixed-language behavior stable

The first phase should focus on `Auto` / `mixed`.

- `.mixed` gets the new fidelity selector
- `.chinese` and `.english` should keep their current behavior unless a small shared helper makes the code simpler

This keeps the change set focused and reduces regression risk.

### 5. Defer prompt-token activation

The code already defines prompt text such as "Do not translate" and "Keep code-switching as spoken", but prompt tokens are currently disabled.

That prompt path should stay disabled in phase one.

Reason:

- it is not currently part of live decoding
- it may have been related to earlier empty-result instability
- the immediate problem can be improved by better mixed-result selection without changing decoder conditioning

Prompt-token activation can be evaluated later as a separate phase once the fidelity selector is stable.

## Non-Goals

Phase one should not:

- redesign transcription into segment-level language routing
- change the model backend
- enable automatic translation
- force mixed output when the speech is actually pure Chinese or pure English
- broaden the work into unrelated transcription cleanup

## Testing Strategy

Add unit coverage for the mixed selector in `Tests/TypelessTests/TranscriptionEngineTests.swift`.

Required scenarios:

- Chinese-led mixed speech stays mixed
- English-led mixed speech stays mixed
- smoother all-English rewrite loses to noisier faithful mixed output
- pure Chinese speech can still resolve to pure Chinese
- pure English speech can still resolve to pure English
- product names and technical terms such as `Slack`, `Figma`, and `Notion` are preserved

The main regression to prevent is:

- user speaks mixed Chinese and English
- `Auto` outputs a fluent full-English sentence that rewrites the utterance

## Implementation Outline

1. Introduce a small transcript-analysis helper for candidate features.
2. Add a mixed-only transcript selection path that uses those features.
3. Keep the existing attempt flow and decoding options unchanged.
4. Add targeted tests for mixed fidelity behavior.

## Expected Outcome

After this change, `Auto` should feel meaningfully closer to "write what I said" instead of "rewrite my speech into one language."

The target is not perfect bilingual recognition. The target is to stop mixed speech from collapsing into a smoother but less faithful single-language transcript.
