import Foundation
import Testing
@testable import Typeless

/// Regression coverage for a lockout observed on 2026-09-04.
///
/// `startDictation` awaits a microphone permission check, and the dictation state stays `.idle`
/// for that whole window. Pressing the shortcut again during it started a second session: the
/// first began recording, the second failed with `alreadyRecording`, and the failure overwrote the
/// running session's state with an error. From there every press restarted instead of stopping,
/// so the recorder kept running while the menu bar reported "No audio captured" — unrecoverable
/// without relaunching the app.
@MainActor
struct DictationToggleRaceTests {
    @Test
    func secondPressDuringPermissionCheckDoesNotBreakTheRunningSession() async {
        let appState = makeAppState()
        let recorder = ExclusiveAudioRecorder()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: SuspendingMicrophonePermissionManager(),
            accessibilityPermissionManager: AlwaysTrustedAccessibilityPermissionManager(),
            audioRecorder: recorder,
            transcriptionEngine: NoopTranscriptionEngine(),
            focusedTextInserter: NoopTextInserter(),
            fallbackTextInserter: NoopFallbackInserter(),
            clipboardStore: NoopClipboardStore()
        )

        // Both presses land while the permission check is still suspended.
        async let first: Void = coordinator.toggleDictation()
        async let second: Void = coordinator.toggleDictation()
        _ = await (first, second)

        #expect(appState.dictationState == .recording)
        #expect(recorder.startCount == 1)
        #expect(appState.lastError == nil)
    }

    /// After the race, the shortcut must still stop the session rather than trying to start again.
    @Test
    func sessionStartedThroughTheRaceCanStillBeStopped() async {
        let appState = makeAppState()
        let recorder = ExclusiveAudioRecorder()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: SuspendingMicrophonePermissionManager(),
            accessibilityPermissionManager: AlwaysTrustedAccessibilityPermissionManager(),
            audioRecorder: recorder,
            transcriptionEngine: NoopTranscriptionEngine(),
            focusedTextInserter: NoopTextInserter(),
            fallbackTextInserter: NoopFallbackInserter(),
            clipboardStore: NoopClipboardStore()
        )

        async let first: Void = coordinator.toggleDictation()
        async let second: Void = coordinator.toggleDictation()
        _ = await (first, second)
        await coordinator.toggleDictation()

        #expect(appState.dictationState == .idle)
        #expect(recorder.isRecording == false)
    }

    /// A recorder left running by any earlier failure must not lock the app out permanently.
    @Test
    func aStaleRecordingSessionIsDiscardedInsteadOfBlockingForever() async {
        let appState = makeAppState()
        let recorder = ExclusiveAudioRecorder()
        try? await recorder.startRecording()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubPermissionManager(),
            accessibilityPermissionManager: AlwaysTrustedAccessibilityPermissionManager(),
            audioRecorder: recorder,
            transcriptionEngine: NoopTranscriptionEngine(),
            focusedTextInserter: NoopTextInserter(),
            fallbackTextInserter: NoopFallbackInserter(),
            clipboardStore: NoopClipboardStore()
        )

        await coordinator.toggleDictation()

        // Recovered rather than stuck in an error the user cannot leave.
        #expect(appState.dictationState == .idle)
        #expect(recorder.isRecording == false)

        await coordinator.toggleDictation()
        #expect(appState.dictationState == .recording)
    }

    private func makeAppState() -> AppState {
        AppState(userDefaults: UserDefaults(suiteName: "ToggleRaceTests-\(UUID().uuidString)")!)
    }
}

/// Rejects a second concurrent session exactly as `AudioRecorder` does. The shared test stub
/// silently accepts one, which is why this race went unnoticed.
private final class ExclusiveAudioRecorder: AudioRecording, @unchecked Sendable {
    private(set) var startCount = 0
    private(set) var isRecording = false

    func startRecording() async throws {
        guard isRecording == false else { throw AudioSessionError.alreadyRecording }
        isRecording = true
        startCount += 1
    }

    func stopRecording() async throws -> RecordedAudioClip {
        guard isRecording else { throw AudioSessionError.missingOutputFile }
        isRecording = false
        return RecordedAudioClip(fileURL: URL(fileURLWithPath: "/tmp/race-test.wav"), duration: 1)
    }
}

/// Suspends the way a real permission check does, holding the state at `.idle` long enough for a
/// second shortcut press to arrive.
private struct SuspendingMicrophonePermissionManager: MicrophonePermissionManaging {
    func currentState() -> PermissionState { .authorized }

    func requestIfNeeded() async -> PermissionState {
        await Task.yield()
        await Task.yield()
        return .authorized
    }
}

private struct StubPermissionManager: MicrophonePermissionManaging {
    func currentState() -> PermissionState { .authorized }
    func requestIfNeeded() async -> PermissionState { .authorized }
}

@MainActor
private final class AlwaysTrustedAccessibilityPermissionManager: AccessibilityPermissionManaging {
    func isTrusted() -> Bool { true }
    func promptIfNeeded() {}
}

@MainActor
private final class NoopTranscriptionEngine: TranscriptionEngine {
    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        TranscriptResult(text: "ok")
    }
}

@MainActor
private final class NoopTextInserter: FocusedTextInserter {
    func captureTarget() -> FocusedInputTarget? { nil }
    func insert(_ text: String) throws {}
    func insert(_ text: String, into target: FocusedInputTarget) throws {}
}

@MainActor
private final class NoopFallbackInserter: FallbackTextInserter {
    func paste(_ text: String, preserveClipboard: Bool) throws {}
}

private final class NoopClipboardStore: ClipboardStoring, @unchecked Sendable {
    func snapshot() -> ClipboardSnapshot? { nil }
    func setText(_ text: String) throws {}
    func restore(_ snapshot: ClipboardSnapshot?) throws {}
}
