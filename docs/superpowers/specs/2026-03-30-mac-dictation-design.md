# macOS Offline Dictation MVP Design

**Date:** 2026-03-30

**Goal:** Build a self-use macOS menu bar app that starts and stops recording with a global shortcut, performs offline Chinese-English mixed-language transcription, and inserts the text into the currently focused input field.

## Product Summary

This project is a personal-use, offline-first macOS dictation utility inspired by products like Typeless, but intentionally scoped down to the smallest version that is both useful and realistic to build.

The first version should:

- Run as a menu bar app
- Use a fixed global shortcut: `Command + Shift + H`
- Toggle recording on first and second shortcut press
- Transcribe spoken Chinese and English, including mixed-language utterances
- Insert the resulting text into the currently focused input field automatically
- Fall back to clipboard paste if direct insertion fails

The first version should not:

- Translate text between languages
- Rewrite or polish text
- Keep a long-term transcript history
- Support many languages beyond Chinese and English
- Offer cloud sync, cloud APIs, or paid AI services

## Success Criteria

The MVP is successful if:

- The app is usable by one person on their own Mac every day
- The shortcut reliably starts and stops recording
- Offline transcription works well enough for Chinese-English mixed speech
- Text insertion works in a useful subset of common apps, especially:
  - Chrome
  - VS Code
  - WeChat
  - Telegram
  - Email composition fields
  - Common text inputs in native and web apps
- Failure cases are recoverable without losing the recognized text

## Recommended Technical Direction

### Recommended Approach

Use:

- `Swift`
- `SwiftUI` plus `AppKit` where needed
- `AVAudioEngine` for audio capture
- `WhisperKit` for offline transcription
- macOS `Accessibility API` for direct text insertion
- Clipboard paste fallback when direct insertion fails

### Why This Approach

This stack best matches the product goals:

- Native macOS APIs fit menu bar behavior, permission handling, and focused-element access
- `WhisperKit` is well aligned with Apple platform app development and offline speech workflows
- The app remains usable without ongoing API costs
- The architecture leaves room to swap transcription backends later without changing the user interaction model

### Alternatives Considered

1. Apple `Speech` framework only
   - Lower dependency surface
   - Weaker confidence for Chinese-English mixed-language transcription quality

2. `whisper.cpp`
   - Strong and mature option
   - More low-level integration work than `WhisperKit` for this product-focused MVP

3. Cloud speech APIs
   - Faster to prototype
   - Adds recurring cost, privacy tradeoffs, and breaks the offline-first requirement

## System Architecture

The app should be organized around a small set of focused modules.

### 1. Menu Bar App

Responsibilities:

- Show idle, recording, transcribing, and error states
- Surface permission guidance
- Provide quit and future settings entry points

### 2. Hotkey Manager

Responsibilities:

- Register the global shortcut `Command + Shift + H`
- Toggle dictation flow on each press

### 3. Audio Recorder

Responsibilities:

- Start microphone capture
- Stop microphone capture
- Produce audio in a format accepted by the transcription engine

### 4. Transcription Engine

Responsibilities:

- Send captured audio to `WhisperKit`
- Return transcript text without translation or stylistic rewriting
- Optimize for Chinese-English mixed-language transcription

### 5. Text Inserter

Responsibilities:

- Detect the current focused UI element
- Attempt direct text insertion through Accessibility APIs

### 6. Fallback Inserter

Responsibilities:

- Copy transcript text to the clipboard
- Trigger paste into the focused field if direct insertion fails

### 7. Dictation Coordinator

Responsibilities:

- Orchestrate the full flow
- Own state transitions
- Handle recoverable failures

## State Model

The MVP should use a minimal state machine:

- `idle`
- `recording`
- `transcribing`
- `inserting`
- `error`

Transitions:

1. `idle -> recording` on first hotkey press
2. `recording -> transcribing` on second hotkey press
3. `transcribing -> inserting` when transcript text is ready
4. `inserting -> idle` on success
5. Any state -> `error` on unrecoverable failure
6. `error -> idle` after user-visible recovery handling completes

## Main User Flow

1. User presses `Command + Shift + H`
2. App verifies required permissions
3. App starts recording and shows recording state
4. User presses `Command + Shift + H` again
5. App stops recording
6. App transcribes the audio offline with `WhisperKit`
7. App attempts to insert the transcript into the current input field
8. If direct insertion fails, app automatically falls back to clipboard paste
9. App returns to idle state

## Permission Model

The MVP depends on two main permission surfaces:

- `Microphone`
- `Accessibility`

### Microphone

Required to capture speech.

### Accessibility

Required to:

- Identify the focused element
- Attempt direct text insertion
- Support UI automation needed for fallback behavior

The onboarding flow should explain clearly why both permissions are needed.

## Input Compatibility Strategy

This is the highest-risk area of the product.

The app should use a two-step insertion strategy:

1. Attempt direct insertion using Accessibility APIs
2. If that fails, use clipboard paste automatically

The MVP should explicitly target "good enough for daily personal use" rather than "works in every app."

Expected priority targets:

- Browser text fields and textareas
- Common web app compose boxes
- Native text controls
- Messaging app compose fields

Known risk targets:

- VS Code editor surfaces
- Electron-based apps
- Custom-rendered compose fields

## Error Handling

The MVP should keep errors simple and actionable.

Primary error classes:

- Missing microphone permission
- Missing accessibility permission
- Empty or unusable captured audio
- Transcription failure
- Direct insertion failure
- Clipboard fallback failure

Error handling rules:

- Missing permissions should trigger user guidance, not silent failure
- Transcription failures should preserve the app session and return to idle
- If insertion fails, fallback should run automatically
- If both insertion methods fail, the transcript should still remain available in memory for manual recovery

## Cost Analysis

### Expected MVP Cost

- Speech API cost: `0`
- Ongoing inference cost: `0`
- Development tool cost: `0` in normal local development
- Model download cost: `0`

### Possible Future Cost

- Apple Developer Program fee if the app is later signed, notarized, or distributed to others
- Optional future cloud API usage if offline transcription proves insufficient

## Feasibility Assessment

### Overall Feasibility

Building a personal-use version of this product is highly feasible.

Estimated feasibility:

- Personal daily-use MVP: high
- Stable mixed Chinese-English offline transcription: high
- Universal compatibility across arbitrary apps: medium

### Why It Is Feasible

- The requested feature set is much smaller than commercial dictation products
- Offline multilingual transcription is practical with Whisper-family models
- Native macOS APIs support the app shell, permissions, and focused-element workflows

### Why It Is Not Trivial

- Inserting text into arbitrary apps is less reliable than the transcription itself
- Some high-priority apps may require fallback behavior to feel dependable
- Latency and perceived responsiveness matter a lot in dictation products

## Key Risks

### Highest Risks

1. Focused-input insertion compatibility across apps
2. Reliability of fallback paste behavior
3. Latency from local transcription model choice
4. Recognition quality for short mixed-language utterances and proper nouns

### Lower Risks

1. Global shortcut registration
2. Menu bar shell
3. Basic microphone recording

## Scope Guardrails

To keep the MVP realistic, avoid adding these in v1:

- Translation mode
- AI rewriting or cleanup
- Transcript history database
- Multiple shortcut profiles
- Auto-stop via silence detection
- Per-app custom insertion logic
- Cross-device sync
- Cloud transcription backup path

## Suggested Build Order

1. Create the menu bar app shell
2. Add global hotkey registration
3. Implement start and stop recording
4. Integrate `WhisperKit` and verify offline transcription quality
5. Show transcript locally first for debugging
6. Add direct insertion using Accessibility
7. Add automatic clipboard paste fallback
8. Test target apps: Chrome, VS Code, WeChat, Telegram, email compose fields
9. Polish permission onboarding and error messaging

## Recommendation

Proceed with a `WhisperKit`-based offline MVP focused on personal daily use.

This is the smallest version that preserves the product's core value:

`press shortcut -> speak Chinese and English naturally -> stop -> text appears in the current input field`

The biggest engineering attention should go to insertion reliability, not extra AI features.
