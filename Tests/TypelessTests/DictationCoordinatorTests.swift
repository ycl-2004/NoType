import Foundation
import Testing
@testable import Typeless

@MainActor
struct DictationCoordinatorTests {
    @Test
    func toggleFromIdleStartsRecording() async {
        let appState = makeTestAppState()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: StubAudioRecorder(),
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .recording)
    }

    @Test
    func toggleFromRecordingReturnsToIdle() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .idle)
    }

    @Test
    func missingAccessibilityPermissionDoesNotBlockRecordingStart() async {
        let appState = makeTestAppState()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: false),
            audioRecorder: StubAudioRecorder(),
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .recording)
    }

    @Test
    func missingAccessibilityPermissionPromptsAndStopsInsertion() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let accessibilityManager = StubAccessibilityPermissionManager(trusted: false)
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: accessibilityManager,
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .error(.accessibilityPermissionRequired))
        #expect(accessibilityManager.prompted == true)
    }

    @Test
    func insertionFailureUsesFallback() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let fallback = StubFallbackInserter()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: FailingFocusedTextInserter(),
            fallbackTextInserter: fallback,
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .idle)
        #expect(fallback.pastedText == "Hello 你好")
        #expect(clipboardStore.text == "Hello 你好")
    }

    @Test
    func selectedRecognitionLanguageIsPassedToTranscriptionEngine() async {
        let appState = makeTestAppState()
        appState.setRecognitionLanguage(.chinese)
        let recorder = StubAudioRecorder()
        let transcriptionEngine = RecordingStubTranscriptionEngine(result: .init(text: "你好"))
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: transcriptionEngine,
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(transcriptionEngine.receivedLanguage == .chinese)
    }

    @Test
    func selectedChineseScriptPreferenceIsPassedToTranscriptionEngine() async {
        let appState = makeTestAppState()
        appState.setChineseScriptPreference(.traditional)
        let recorder = StubAudioRecorder()
        let transcriptionEngine = RecordingStubTranscriptionEngine(result: .init(text: "你好"))
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: transcriptionEngine,
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(transcriptionEngine.receivedChineseScriptPreference == .traditional)
    }

    @Test
    func successfulInsertionStillUpdatesClipboard() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter(),
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .idle)
        #expect(clipboardStore.text == "Hello 你好")
    }

    @Test
    func insertionUsesCapturedInputTargetWhenAvailable() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let focusedTextInserter = RecordingFocusedTextInserter(capturedTarget: FocusedInputTarget(element: nil, debugDescription: "chat-input"))
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: focusedTextInserter,
            fallbackTextInserter: StubFallbackInserter()
        )

        await coordinator.toggleDictation()
        try? await recorder.startRecording()
        appState.update(for: .recording)

        await coordinator.toggleDictation()

        #expect(focusedTextInserter.insertedIntoCapturedTargetText == "Hello 你好")
        #expect(focusedTextInserter.insertedText == nil)
    }

    @Test
    func insertionFallsBackToCurrentFocusWhenCapturedTargetInsertFails() async {
        let appState = makeTestAppState()
        let recorder = StubAudioRecorder()
        let focusedTextInserter = RecordingFocusedTextInserter(
            capturedTarget: FocusedInputTarget(element: nil, debugDescription: "chat-input"),
            failCapturedInsert: true
        )
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: focusedTextInserter,
            fallbackTextInserter: StubFallbackInserter()
        )

        await coordinator.toggleDictation()
        try? await recorder.startRecording()
        appState.update(for: .recording)

        await coordinator.toggleDictation()

        #expect(focusedTextInserter.insertedIntoCapturedTargetText == nil)
        #expect(focusedTextInserter.insertedText == nil)
        #expect(appState.statusText == "Original chat changed, transcript copied")
    }

    @Test
    func insertOnlyModeCopiesTranscriptWhenCapturedTargetChanges() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.transcriptInserted)
        let recorder = StubAudioRecorder()
        let clipboardStore = StubClipboardStore()
        let focusedTextInserter = RecordingFocusedTextInserter(
            capturedTarget: FocusedInputTarget(element: nil, debugDescription: "chat-input"),
            failCapturedInsert: true
        )
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: focusedTextInserter,
            fallbackTextInserter: StubFallbackInserter(),
            clipboardStore: clipboardStore
        )

        await coordinator.toggleDictation()
        try? await recorder.startRecording()
        appState.update(for: .recording)

        await coordinator.toggleDictation()

        #expect(clipboardStore.text == "Hello 你好")
        #expect(appState.statusText == "Original chat changed, transcript copied")
        #expect(appState.lastDebugMessage == "Original input changed during dictation; transcript copied to clipboard")
    }

    @Test
    func successfulDictationUsesSelectedSuccessStatusMode() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.transcriptCopied)
        let recorder = StubAudioRecorder()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.statusText == "Transcript copied")
    }

    @Test
    func transcriptCopiedModeDoesNotInsertText() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.transcriptCopied)
        let recorder = StubAudioRecorder()
        let focusedTextInserter = RecordingFocusedTextInserter()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: focusedTextInserter,
            fallbackTextInserter: StubFallbackInserter(),
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(clipboardStore.text == "Hello 你好")
        #expect(focusedTextInserter.insertedText == nil)
    }

    @Test
    func transcriptInsertedModeDoesNotSyncClipboardOrPasteFallback() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.transcriptInserted)
        let recorder = StubAudioRecorder()
        let focusedTextInserter = RecordingFocusedTextInserter()
        let fallback = StubFallbackInserter()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: focusedTextInserter,
            fallbackTextInserter: fallback,
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(focusedTextInserter.insertedText == "Hello 你好")
        #expect(clipboardStore.text == nil)
        #expect(fallback.pastedText == nil)
    }

    @Test
    func transcriptInsertedModeFallsBackToPasteWhenDirectInsertIsUnsupported() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.transcriptInserted)
        let recorder = StubAudioRecorder()
        let fallback = StubFallbackInserter()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: FailingFocusedTextInserter(),
            fallbackTextInserter: fallback,
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(appState.dictationState == .idle)
        #expect(fallback.pastedText == "Hello 你好")
        #expect(fallback.preserveClipboard == true)
        #expect(clipboardStore.text == nil)
        #expect(appState.statusText == "Transcript inserted")
    }

    @Test
    func bothModeFallbackStillLeavesTranscriptInClipboard() async {
        let appState = makeTestAppState()
        appState.setSuccessStatusMode(.both)
        let recorder = StubAudioRecorder()
        let fallback = StubFallbackInserter()
        let clipboardStore = StubClipboardStore()
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: StubTranscriptionEngine(result: .init(text: "Hello 你好")),
            focusedTextInserter: FailingFocusedTextInserter(),
            fallbackTextInserter: fallback,
            clipboardStore: clipboardStore
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(fallback.pastedText == "Hello 你好")
        #expect(fallback.preserveClipboard == false)
        #expect(clipboardStore.text == "Hello 你好")
    }

    @Test
    func selectedMixedRecognitionLanguageIsPassedToTranscriptionEngine() async {
        let appState = makeTestAppState()
        appState.setRecognitionLanguage(.mixed)
        let recorder = StubAudioRecorder()
        let transcriptionEngine = RecordingStubTranscriptionEngine(result: .init(text: "I like 西瓜"))
        let coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: StubMicrophonePermissionManager(state: .authorized),
            accessibilityPermissionManager: StubAccessibilityPermissionManager(trusted: true),
            audioRecorder: recorder,
            transcriptionEngine: transcriptionEngine,
            focusedTextInserter: StubFocusedTextInserter(),
            fallbackTextInserter: StubFallbackInserter()
        )
        appState.update(for: .recording)
        try? await recorder.startRecording()

        await coordinator.toggleDictation()

        #expect(transcriptionEngine.receivedLanguage == .mixed)
    }
}

@MainActor
private final class StubAudioRecorder: AudioRecording, @unchecked Sendable {
    private var started = false

    func startRecording() async throws {
        started = true
    }

    func stopRecording() async throws -> RecordedAudioClip {
        let url = URL(fileURLWithPath: "/tmp/fake.wav")
        guard started else {
            throw AudioSessionError.missingOutputFile
        }
        started = false
        return RecordedAudioClip(fileURL: url)
    }
}

private struct StubMicrophonePermissionManager: MicrophonePermissionManaging {
    let state: PermissionState

    func currentState() -> PermissionState { state }
    func requestIfNeeded() async -> PermissionState { state }
}

@MainActor
private final class StubAccessibilityPermissionManager: AccessibilityPermissionManaging {
    let trusted: Bool
    private(set) var prompted = false

    init(trusted: Bool) {
        self.trusted = trusted
    }

    func isTrusted() -> Bool { trusted }
    func promptIfNeeded() {
        prompted = true
    }
}

private struct StubTranscriptionEngine: TranscriptionEngine {
    let result: TranscriptResult

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference _: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        result
    }
}

@MainActor
private final class RecordingStubTranscriptionEngine: TranscriptionEngine {
    let result: TranscriptResult
    private(set) var receivedLanguage: DictationRecognitionLanguage?
    private(set) var receivedChineseScriptPreference: ChineseScriptPreference?

    init(result: TranscriptResult) {
        self.result = result
    }

    func transcribe(
        _ clip: RecordedAudioClip,
        language: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference
    ) async throws -> TranscriptResult {
        receivedLanguage = language
        receivedChineseScriptPreference = chineseScriptPreference
        return result
    }
}

private struct StubFocusedTextInserter: FocusedTextInserter {
    func captureTarget() -> FocusedInputTarget? { nil }
    func insert(_ text: String) throws {}
    func insert(_ text: String, into target: FocusedInputTarget) throws {}
}

@MainActor
private final class RecordingFocusedTextInserter: FocusedTextInserter {
    private(set) var insertedText: String?
    private(set) var insertedIntoCapturedTargetText: String?
    private let capturedTarget: FocusedInputTarget?
    private let failCapturedInsert: Bool

    init(
        capturedTarget: FocusedInputTarget? = nil,
        failCapturedInsert: Bool = false
    ) {
        self.capturedTarget = capturedTarget
        self.failCapturedInsert = failCapturedInsert
    }

    func captureTarget() -> FocusedInputTarget? {
        capturedTarget
    }

    func insert(_ text: String) throws {
        insertedText = text
    }

    func insert(_ text: String, into target: FocusedInputTarget) throws {
        if failCapturedInsert {
            throw InsertionError.unsupportedFocusedElement
        }

        insertedIntoCapturedTargetText = text
    }
}

@MainActor
private final class StubFallbackInserter: FallbackTextInserter {
    private(set) var pastedText: String?
    private(set) var preserveClipboard: Bool?

    func paste(_ text: String, preserveClipboard: Bool) throws {
        pastedText = text
        self.preserveClipboard = preserveClipboard
    }
}

@MainActor
private final class StubClipboardStore: ClipboardStoring {
    private(set) var text: String?
    private(set) var restoredSnapshot: ClipboardSnapshot?

    func snapshot() -> ClipboardSnapshot? {
        text.map { ClipboardSnapshot(items: [ClipboardSnapshotItem(representations: [.string: Data($0.utf8)])]) }
    }

    func setText(_ text: String) throws {
        self.text = text
    }

    func restore(_ snapshot: ClipboardSnapshot?) throws {
        restoredSnapshot = snapshot
        guard let snapshot,
              let item = snapshot.items.first,
              let data = item.representations[.string],
              let restoredText = String(data: data, encoding: .utf8) else {
            text = nil
            return
        }

        text = restoredText
    }
}

private struct FailingFocusedTextInserter: FocusedTextInserter {
    func captureTarget() -> FocusedInputTarget? { nil }
    func insert(_ text: String) throws {
        throw InsertionError.unsupportedFocusedElement
    }

    func insert(_ text: String, into target: FocusedInputTarget) throws {
        throw InsertionError.unsupportedFocusedElement
    }
}

@MainActor
private func makeTestAppState() -> AppState {
    let suiteName = "DictationCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return AppState(userDefaults: defaults)
}
