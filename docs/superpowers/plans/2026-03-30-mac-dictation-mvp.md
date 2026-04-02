# macOS Offline Dictation MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-use macOS menu bar app that records speech with a global shortcut, performs offline Chinese-English mixed-language transcription, and inserts the result into the currently focused input field.

**Architecture:** The app is a native macOS menu bar application built in Swift. It is organized around a coordinator that manages five focused subsystems: hotkey handling, audio recording, offline transcription with WhisperKit, focused-text insertion via Accessibility APIs, and clipboard paste fallback when direct insertion fails.

**Tech Stack:** Swift, SwiftUI, AppKit, AVAudioEngine, WhisperKit, Accessibility API, XCTest

---
## File Structure

This project starts from an empty directory. Keep the first version small and explicit.

### App Shell

- Create: `Typeless.xcodeproj`
- Create: `Typeless/TypelessApp.swift`
- Create: `Typeless/App/AppDelegate.swift`
- Create: `Typeless/App/AppState.swift`
- Create: `Typeless/App/MenuBar/MenuBarController.swift`

Responsibilities:

- Create the menu bar app entry point
- Own app lifecycle and visible status
- Provide a minimal menu for status, permissions, and quit

### Dictation Flow

- Create: `Typeless/Domain/DictationState.swift`
- Create: `Typeless/Domain/DictationError.swift`
- Create: `Typeless/Domain/TranscriptResult.swift`
- Create: `Typeless/Coordinator/DictationCoordinator.swift`

Responsibilities:

- Centralize state transitions
- Sequence recording, transcription, insertion, and recovery
- Surface state and errors to the UI layer

### Hotkey

- Create: `Typeless/Hotkey/GlobalHotkeyManager.swift`
- Create: `Typeless/Hotkey/KeyCombination.swift`

Responsibilities:

- Register the global shortcut `Command + Shift + H`
- Deliver toggle events to the coordinator

### Audio

- Create: `Typeless/Audio/AudioRecorder.swift`
- Create: `Typeless/Audio/AudioSessionError.swift`
- Create: `Typeless/Audio/RecordedAudioClip.swift`

Responsibilities:

- Start and stop capture with `AVAudioEngine`
- Write or expose recorded audio in a transcription-ready format

### Transcription

- Create: `Typeless/Transcription/TranscriptionEngine.swift`
- Create: `Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Create: `Typeless/Transcription/TranscriptionError.swift`

Responsibilities:

- Abstract transcription behavior behind a small interface
- Implement offline WhisperKit transcription
- Preserve original spoken language instead of translating or rewriting

### Focused Text Insertion

- Create: `Typeless/Accessibility/FocusedTextInserter.swift`
- Create: `Typeless/Accessibility/AccessibilityTextInserter.swift`
- Create: `Typeless/Accessibility/ClipboardPasteFallback.swift`
- Create: `Typeless/Accessibility/AccessibilityPermissionManager.swift`
- Create: `Typeless/Accessibility/InsertionError.swift`

Responsibilities:

- Check Accessibility permission
- Attempt direct insertion into the focused element
- Fall back to clipboard paste when needed

### Permissions

- Create: `Typeless/Permissions/MicrophonePermissionManager.swift`
- Create: `Typeless/Permissions/PermissionState.swift`

Responsibilities:

- Check and request microphone permission
- Report combined permission readiness to the app and coordinator

### Testing

- Create: `TypelessTests/DictationCoordinatorTests.swift`
- Create: `TypelessTests/AppStateTests.swift`
- Create: `TypelessTests/TranscriptionEngineTests.swift`

Responsibilities:

- Verify state transitions and failure handling
- Verify coordinator fallback behavior using test doubles

## Task 1: Create the App Shell

**Files:**

- Create: `Typeless.xcodeproj`
- Create: `Typeless/TypelessApp.swift`
- Create: `Typeless/App/AppDelegate.swift`
- Create: `Typeless/App/AppState.swift`
- Create: `Typeless/App/MenuBar/MenuBarController.swift`

- [ ] **Step 1: Create the Xcode macOS app project**

Create a native macOS app project named `Typeless` with Swift and SwiftUI enabled.

- [ ] **Step 2: Add the app entry point**

Create `Typeless/TypelessApp.swift` with a minimal app shell that boots the app state and menu bar controller.

- [ ] **Step 3: Add a shared observable app state**

Create `Typeless/App/AppState.swift` to expose:

```swift
@MainActor
final class AppState: ObservableObject {
    @Published var dictationState: DictationState = .idle
    @Published var lastError: DictationError?
    @Published var statusText: String = "Idle"
}
```

- [ ] **Step 4: Add a minimal menu bar UI**

Create `Typeless/App/MenuBar/MenuBarController.swift` with a menu showing:

- Current status
- Permissions entry point
- Quit action

- [ ] **Step 5: Run the app**

Run the app from Xcode.

Expected:

- App launches
- Menu bar item appears
- Quit action works

- [ ] **Step 6: Commit**

```bash
git add Typeless.xcodeproj Typeless
git commit -m "feat: scaffold macOS menu bar app shell"
```

## Task 2: Define the Domain Model and Coordinator

**Files:**

- Create: `Typeless/Domain/DictationState.swift`
- Create: `Typeless/Domain/DictationError.swift`
- Create: `Typeless/Domain/TranscriptResult.swift`
- Create: `Typeless/Coordinator/DictationCoordinator.swift`
- Test: `TypelessTests/DictationCoordinatorTests.swift`

- [ ] **Step 1: Write the failing coordinator state test**

Create `TypelessTests/DictationCoordinatorTests.swift`:

```swift
func test_toggle_fromIdle_startsRecording() async throws
func test_toggle_fromRecording_stopsAndTranscribes() async throws
func test_insertionFailure_usesFallback() async throws
```

- [ ] **Step 2: Run the test target**

Run:

```bash
xcodebuild test -scheme Typeless -destination 'platform=macOS'
```

Expected:

- Tests fail because coordinator and collaborators do not exist yet

- [ ] **Step 3: Add the core state types**

Create:

```swift
enum DictationState {
    case idle
    case recording
    case transcribing
    case inserting
    case error(DictationError)
}
```

and focused error/result types.

- [ ] **Step 4: Add a minimal coordinator**

Create a coordinator with injectable dependencies:

```swift
@MainActor
final class DictationCoordinator {
    func toggleDictation() async
}
```

Dependencies should include recorder, transcription engine, direct inserter, fallback inserter, and permission managers.

- [ ] **Step 5: Run tests again**

Run:

```bash
xcodebuild test -scheme Typeless -destination 'platform=macOS'
```

Expected:

- Coordinator tests pass or narrow to the next missing implementation details

- [ ] **Step 6: Commit**

```bash
git add Typeless TypelessTests
git commit -m "feat: add dictation coordinator and domain model"
```

## Task 3: Add Global Hotkey Support

**Files:**

- Create: `Typeless/Hotkey/GlobalHotkeyManager.swift`
- Create: `Typeless/Hotkey/KeyCombination.swift`
- Modify: `Typeless/TypelessApp.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`

- [ ] **Step 1: Write a narrow integration test or manual verification note**

If unit-testing global hotkeys is awkward, document manual verification steps in code comments and keep the manager interface small.

- [ ] **Step 2: Add a key combination type**

Create:

```swift
struct KeyCombination {
    let keyCode: UInt32
    let modifiers: UInt32
}
```

- [ ] **Step 3: Implement the global hotkey manager**

Expose a callback that triggers when `Command + Shift + H` is pressed.

- [ ] **Step 4: Wire the hotkey to the coordinator**

When the hotkey fires, call:

```swift
Task { await coordinator.toggleDictation() }
```

- [ ] **Step 5: Run the app and test manually**

Expected:

- Pressing `Command + Shift + H` changes the state to recording
- Pressing it again returns to a non-recording path without crashing

- [ ] **Step 6: Commit**

```bash
git add Typeless
git commit -m "feat: add global dictation hotkey"
```

## Task 4: Implement Microphone Permission and Audio Recording

**Files:**

- Create: `Typeless/Permissions/MicrophonePermissionManager.swift`
- Create: `Typeless/Permissions/PermissionState.swift`
- Create: `Typeless/Audio/AudioRecorder.swift`
- Create: `Typeless/Audio/AudioSessionError.swift`
- Create: `Typeless/Audio/RecordedAudioClip.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`
- Test: `TypelessTests/DictationCoordinatorTests.swift`

- [ ] **Step 1: Write the failing permission and recording tests**

Add tests that verify:

- recording cannot start without permission
- stopping after a recording returns an audio clip

- [ ] **Step 2: Implement microphone permission manager**

Expose:

```swift
protocol MicrophonePermissionManaging {
    func currentState() async -> PermissionState
    func requestIfNeeded() async -> PermissionState
}
```

- [ ] **Step 3: Implement the audio recorder**

Expose:

```swift
protocol AudioRecording {
    func startRecording() async throws
    func stopRecording() async throws -> RecordedAudioClip
}
```

Use `AVAudioEngine` and a simple output format that WhisperKit can consume.

- [ ] **Step 4: Wire microphone permission checks into the coordinator**

Expected behavior:

- Missing permission moves to a user-visible error
- Granted permission starts recording

- [ ] **Step 5: Run tests and manual recording checks**

Run:

```bash
xcodebuild test -scheme Typeless -destination 'platform=macOS'
```

Manual check:

- First press requests or validates microphone access
- Recording starts and stops without app crash

- [ ] **Step 6: Commit**

```bash
git add Typeless TypelessTests
git commit -m "feat: add microphone permission and recording"
```

## Task 5: Integrate WhisperKit for Offline Transcription

**Files:**

- Create: `Typeless/Transcription/TranscriptionEngine.swift`
- Create: `Typeless/Transcription/WhisperKitTranscriptionEngine.swift`
- Create: `Typeless/Transcription/TranscriptionError.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`
- Test: `TypelessTests/TranscriptionEngineTests.swift`

- [ ] **Step 1: Add the WhisperKit dependency**

Add `WhisperKit` using Swift Package Manager in Xcode.

- [ ] **Step 2: Write the failing transcription abstraction test**

Create tests around:

```swift
func test_transcriptionEngine_returnsTranscriptText() async throws
func test_transcriptionFailure_surfacesError() async throws
```

Use test doubles rather than real model inference in unit tests.

- [ ] **Step 3: Define the transcription protocol**

```swift
protocol TranscriptionEngine {
    func transcribe(_ clip: RecordedAudioClip) async throws -> TranscriptResult
}
```

- [ ] **Step 4: Implement `WhisperKitTranscriptionEngine`**

Requirements:

- Use offline transcription only
- Preserve multilingual output
- Do not auto-translate
- Return plain recognized text

- [ ] **Step 5: Add temporary debug output**

While integration is being validated, show the transcript in the menu bar or logs before insertion.

- [ ] **Step 6: Run tests and manual validation**

Run:

```bash
xcodebuild test -scheme Typeless -destination 'platform=macOS'
```

Manual check:

- Speak a short Chinese-English mixed sentence
- Confirm transcript is returned locally

- [ ] **Step 7: Commit**

```bash
git add Typeless TypelessTests
git commit -m "feat: add offline WhisperKit transcription"
```

## Task 6: Implement Accessibility Permission and Direct Text Insertion

**Files:**

- Create: `Typeless/Accessibility/FocusedTextInserter.swift`
- Create: `Typeless/Accessibility/AccessibilityTextInserter.swift`
- Create: `Typeless/Accessibility/AccessibilityPermissionManager.swift`
- Create: `Typeless/Accessibility/InsertionError.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`
- Test: `TypelessTests/DictationCoordinatorTests.swift`

- [ ] **Step 1: Write the failing insertion tests**

Add tests covering:

- missing accessibility permission surfaces an error
- insertion success returns app state to idle

- [ ] **Step 2: Implement accessibility permission checks**

Expose:

```swift
protocol AccessibilityPermissionManaging {
    func isTrusted() -> Bool
    func promptIfNeeded()
}
```

- [ ] **Step 3: Implement direct text insertion**

Create a focused-text insertion protocol:

```swift
protocol FocusedTextInserter {
    func insert(_ text: String) throws
}
```

Use Accessibility APIs to locate the focused element and set its text content if supported.

- [ ] **Step 4: Wire insertion into the coordinator**

Expected behavior:

- After transcription, attempt direct insertion first

- [ ] **Step 5: Run tests and manual checks**

Manual targets:

- Browser input
- Notes or another native text field

- [ ] **Step 6: Commit**

```bash
git add Typeless TypelessTests
git commit -m "feat: add accessibility-based text insertion"
```

## Task 7: Add Clipboard Paste Fallback

**Files:**

- Create: `Typeless/Accessibility/ClipboardPasteFallback.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`
- Modify: `TypelessTests/DictationCoordinatorTests.swift`

- [ ] **Step 1: Write the failing fallback test**

Add a test that verifies:

- when direct insertion throws, the fallback path is called

- [ ] **Step 2: Implement the fallback inserter**

Expose:

```swift
protocol FallbackTextInserter {
    func paste(_ text: String) throws
}
```

Implementation requirements:

- Save current clipboard contents
- Copy transcript text
- Trigger paste into the focused app
- Restore clipboard if practical after paste

- [ ] **Step 3: Wire fallback into the coordinator**

Behavior:

- Attempt direct insertion
- On failure, try fallback automatically
- If fallback also fails, surface a final insertion error

- [ ] **Step 4: Run tests and manual validation**

Manual targets:

- One app where direct insertion works
- One app where fallback is needed

- [ ] **Step 5: Commit**

```bash
git add Typeless TypelessTests
git commit -m "feat: add clipboard paste fallback"
```

## Task 8: Polish Status, Permission Guidance, and Error Messaging

**Files:**

- Modify: `Typeless/App/AppState.swift`
- Modify: `Typeless/App/MenuBar/MenuBarController.swift`
- Modify: `Typeless/Coordinator/DictationCoordinator.swift`

- [ ] **Step 1: Add clear user-facing status labels**

Examples:

- `Idle`
- `Recording...`
- `Transcribing...`
- `Inserting text...`
- `Microphone permission required`
- `Accessibility permission required`

- [ ] **Step 2: Add permission guidance actions**

Provide menu entries or guidance text that tells the user where to enable missing permissions.

- [ ] **Step 3: Reduce debug-only noise**

Keep logs, but avoid leaking internal-only debugging details into the visible UI.

- [ ] **Step 4: Run manual end-to-end checks**

Verify:

- state changes are understandable
- permission failures are actionable
- successful runs feel clean

- [ ] **Step 5: Commit**

```bash
git add Typeless
git commit -m "feat: polish status and permission guidance"
```

## Task 9: Verify Target Apps and Document Known Limits

**Files:**

- Create: `README.md`
- Modify: `Typeless/App/MenuBar/MenuBarController.swift`

- [ ] **Step 1: Manually test the target apps**

Test at minimum:

- Chrome
- VS Code
- WeChat
- Telegram
- one email composition surface

Record whether each app works via direct insertion or fallback.

- [ ] **Step 2: Document known limits**

In `README.md`, document:

- supported first-version workflow
- permissions needed
- known app compatibility limitations
- current shortcut

- [ ] **Step 3: Run a final test pass**

Run:

```bash
xcodebuild test -scheme Typeless -destination 'platform=macOS'
```

Expected:

- automated tests pass
- manual target app notes are captured

- [ ] **Step 4: Commit**

```bash
git add README.md Typeless
git commit -m "docs: add usage notes and known limitations"
```

## Final Verification Checklist

- [ ] App launches as a menu bar utility
- [ ] `Command + Shift + H` toggles recording
- [ ] Microphone permission flow works
- [ ] Accessibility permission flow works
- [ ] WhisperKit transcribes offline
- [ ] Chinese-English mixed speech is preserved as spoken text
- [ ] Direct insertion works in at least one common target app
- [ ] Clipboard fallback works when direct insertion fails
- [ ] Coordinator tests pass
- [ ] Known limitations are documented

## Execution Notes

- Keep the first version single-user and local-only
- Do not add translation, rewriting, or transcript history during MVP implementation
- Prefer dependency injection and protocol boundaries at subsystem seams so the coordinator remains testable
- Validate transcription quality before spending time on extra menu bar polish
