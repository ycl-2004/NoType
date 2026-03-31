# Mixed Transcription Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile mixed-language decode configuration with a fallback-based strategy that restores usable transcription results more reliably.

**Architecture:** Keep `WhisperKit` as the backend and move mixed-language behavior into a small, testable fallback planner inside the transcription engine. The engine will try automatic language handling first, then fall back to forced Chinese and forced English only when the earlier attempt returns no usable text.

**Tech Stack:** Swift, Swift Testing, WhisperKit

---

### Task 1: Add tests for mixed attempt planning

**Files:**
- Modify: `Tests/TypelessTests/TranscriptionEngineTests.swift`
- Test: `Tests/TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Write failing tests**
- [ ] **Step 2: Run the transcription engine tests and verify the new tests fail**
- [ ] **Step 3: Implement the minimal planning helpers in the transcription engine**
- [ ] **Step 4: Re-run the transcription engine tests and verify they pass**

### Task 2: Implement mixed fallback execution

**Files:**
- Modify: `Sources/Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Test: `Tests/TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Write a failing test for identifying empty mixed results**
- [ ] **Step 2: Run the transcription engine tests and verify the new test fails**
- [ ] **Step 3: Implement the mixed fallback execution helpers and option builders**
- [ ] **Step 4: Re-run the transcription engine tests and verify they pass**

### Task 3: Verify app-level behavior remains intact

**Files:**
- Modify: `Tests/TypelessTests/DictationCoordinatorTests.swift`
- Test: `Tests/TypelessTests/DictationCoordinatorTests.swift`

- [ ] **Step 1: Add a focused regression test that confirms coordinator behavior still depends on successful transcription output**
- [ ] **Step 2: Run the coordinator test and verify it passes**
- [ ] **Step 3: Run the full relevant test suite and verify all tests pass**
