# Mixed Transcription Strategy Design

**Date:** 2026-03-30

**Goal:** Improve self-use mixed Chinese-English dictation reliability without making the app noticeably slower.

## Context

The current `Mixed` mode in the app uses `WhisperKit` with:

- `language = "zh"`
- `detectLanguage = false`
- a custom bilingual prompt encoded as `promptTokens`

This is currently the most likely cause of the observed failure mode where transcription returns no usable text and the rest of the insertion pipeline never runs.

For this project, the priority is:

- self-use only
- one utterance may contain both Chinese and English
- noticeably better reliability than the current implementation
- no major latency regression
- no immediate need to optimize for redistribution to other users

## Decision

Keep `WhisperKit` as the backend for now, and replace the current `Mixed` decoding strategy with a fallback-based approach.

Do **not** switch to `whisper.cpp`, `faster-whisper`, or `MLX Whisper` in this iteration.

## Why This Is The Best Near-Term Choice

### Recommended Approach

Use a three-step mixed-language transcription strategy:

1. Try `Mixed` with automatic language handling
2. If transcription is empty or effectively empty, retry as Chinese
3. If that still fails, retry as English

This preserves the current architecture and has the best chance of restoring day-to-day usability quickly.

### Why Not Keep The Current Mixed Strategy

The current design forces the model toward Chinese while also relying on prompt-based conditioning for code-switching. That combination is fragile, and `promptTokens` are a plausible direct cause of empty results in the current `WhisperKit` path.

### Why Not Switch Backends Yet

`whisper.cpp` is the strongest fallback backend if `WhisperKit` remains unsatisfactory, but migrating now would add integration work before validating whether the current failure is mostly caused by decode configuration.

For a self-use app, it is more efficient to first remove the risky parts of the current decoding setup and measure whether reliability becomes acceptable.

## Proposed Mixed Strategy

### Attempt 1: Auto Mixed

For `Mixed` mode:

- `language = nil`
- `detectLanguage = true`
- `usePrefillPrompt = true`
- no custom `promptTokens`

This gives the model the best chance to identify the dominant language behavior for the clip without forcing the decode toward one language or injecting fragile prompt conditioning.

### Attempt 2: Forced Chinese Fallback

If the first attempt returns:

- empty text
- whitespace-only text
- or effectively no body text after trimming

retry with:

- `language = "zh"`
- `detectLanguage = false`
- no custom `promptTokens`

Chinese is the first fallback because the user’s target scenario includes Mandarin dictation and Chinese-led mixed utterances.

### Attempt 3: Forced English Fallback

If the Chinese fallback still returns no useful text, retry with:

- `language = "en"`
- `detectLanguage = false`
- no custom `promptTokens`

This catches cases where the utterance is mostly English or the auto attempt incorrectly fails to settle on a useful decode path.

## Scope Of Change

The implementation should remain narrowly focused.

### In Scope

- `WhisperKitTranscriptionEngine` mixed-language decode behavior
- fallback sequencing for mixed recognition
- logging that records which attempt succeeded
- tests for the new fallback behavior

### Out Of Scope

- switching transcription backend
- changing insertion logic
- changing clipboard synchronization
- adding cloud transcription
- redesigning the language menu

## Expected User Impact

If this works as intended:

- the current “no text” failure should happen less often
- successful transcripts will once again flow into insertion and clipboard sync
- mixed dictation should feel more dependable without a large speed penalty

The user experience goal is not perfect bilingual recognition. The goal is to stop the whole dictation flow from collapsing when the first mixed decode attempt fails.

## Observability

Add lightweight logs for:

- which mixed attempt is running
- whether the result was empty
- which attempt finally succeeded

This will make it much easier to decide later whether `WhisperKit` is good enough or whether a `whisper.cpp` migration is justified.

## Future Decision Gate

After implementing this strategy, evaluate it using real self-use dictation examples.

If mixed utterances still frequently:

- drop one language
- terminate early
- or return unusable text

then the next recommended step is to evaluate `whisper.cpp` as the replacement backend.

That would become a separate design and implementation effort.
