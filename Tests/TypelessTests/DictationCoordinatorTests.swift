import Foundation
import Testing
@testable import Typeless

@MainActor
struct DictationCoordinatorTests {
    @Test
    func toggleFromIdleStartsRecording() async {
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
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
        let appState = AppState()
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
    func successfulInsertionStillUpdatesClipboard() async {
        let appState = AppState()
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
    func successfulDictationUsesSelectedSuccessStatusMode() async {
        let appState = AppState()
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
    func selectedMixedRecognitionLanguageIsPassedToTranscriptionEngine() async {
        let appState = AppState()
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

    func currentState() async -> PermissionState { state }
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

    func transcribe(_ clip: RecordedAudioClip, language: DictationRecognitionLanguage) async throws -> TranscriptResult {
        result
    }
}

@MainActor
private final class RecordingStubTranscriptionEngine: TranscriptionEngine {
    let result: TranscriptResult
    private(set) var receivedLanguage: DictationRecognitionLanguage?

    init(result: TranscriptResult) {
        self.result = result
    }

    func transcribe(_ clip: RecordedAudioClip, language: DictationRecognitionLanguage) async throws -> TranscriptResult {
        receivedLanguage = language
        return result
    }
}

private struct StubFocusedTextInserter: FocusedTextInserter {
    func insert(_ text: String) throws {}
}

@MainActor
private final class StubFallbackInserter: FallbackTextInserter {
    private(set) var pastedText: String?

    func paste(_ text: String) throws {
        pastedText = text
    }
}

@MainActor
private final class StubClipboardStore: ClipboardStoring {
    private(set) var text: String?

    func setText(_ text: String) throws {
        self.text = text
    }
}

private struct FailingFocusedTextInserter: FocusedTextInserter {
    func insert(_ text: String) throws {
        throw InsertionError.unsupportedFocusedElement
    }
}
