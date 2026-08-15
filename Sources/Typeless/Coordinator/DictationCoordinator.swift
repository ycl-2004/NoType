import AppKit
import Foundation

@MainActor
final class DictationCoordinator {
    private enum InsertOutcome {
        case usedSelectedMode
        case copiedBecauseTargetChanged

        var statusText: String {
            switch self {
            case .usedSelectedMode:
                ""
            case .copiedBecauseTargetChanged:
                "Original chat changed, transcript copied"
            }
        }

        var debugMessage: String {
            switch self {
            case .usedSelectedMode:
                "Transcript ready"
            case .copiedBecauseTargetChanged:
                "Original input changed during dictation; transcript copied to clipboard"
            }
        }
    }

    /// Recording stops itself after this long so a forgotten session cannot run unbounded.
    static let maximumRecordingDuration: TimeInterval = 300

    /// Anything shorter than this cannot contain speech — it is a mistrigger, a key bounce, or a
    /// cough. Transcribing it only invites a hallucinated sign-off.
    static let minimumClipDuration: TimeInterval = 0.3

    private let appState: AppState
    private let microphonePermissionManager: MicrophonePermissionManaging
    private let accessibilityPermissionManager: AccessibilityPermissionManaging
    private let audioRecorder: AudioRecording
    private let transcriptionEngine: TranscriptionEngine
    private let focusedTextInserter: FocusedTextInserter
    private let fallbackTextInserter: FallbackTextInserter
    private let clipboardStore: ClipboardStoring
    private var targetApplication: NSRunningApplication?
    private var targetInput: FocusedInputTarget?
    private var recordingTimeoutTask: Task<Void, Never>?

    init(
        appState: AppState,
        microphonePermissionManager: MicrophonePermissionManaging = MicrophonePermissionManager(),
        accessibilityPermissionManager: AccessibilityPermissionManaging = AccessibilityPermissionManager(),
        audioRecorder: AudioRecording = AudioRecorder(),
        transcriptionEngine: TranscriptionEngine = WhisperKitTranscriptionEngine(),
        focusedTextInserter: FocusedTextInserter = AccessibilityTextInserter(),
        fallbackTextInserter: FallbackTextInserter = ClipboardPasteFallback(),
        clipboardStore: ClipboardStoring = ClipboardStore()
    ) {
        self.appState = appState
        self.microphonePermissionManager = microphonePermissionManager
        self.accessibilityPermissionManager = accessibilityPermissionManager
        self.audioRecorder = audioRecorder
        self.transcriptionEngine = transcriptionEngine
        self.focusedTextInserter = focusedTextInserter
        self.fallbackTextInserter = fallbackTextInserter
        self.clipboardStore = clipboardStore
    }

    /// Loads the model in the background at launch so the first dictation does not pay for it.
    func prepareForFirstDictation() async {
        appState.setDebugMessage("Preloading transcription model")
        AppLogger.log("prepareForFirstDictation: preloading transcription model")
        await transcriptionEngine.prewarm()
        appState.setDebugMessage("Transcription model ready")
        AppLogger.log("prepareForFirstDictation: transcription model ready")
    }

    func toggleDictation() async {
        AppLogger.log("toggleDictation called in state=\(String(describing: appState.dictationState))")
        switch appState.dictationState {
        case .idle, .error:
            await startDictation()
        case .recording:
            await stopDictation()
        case .transcribing, .inserting:
            break
        }
    }

    private func startDictation() async {
        targetApplication = captureTargetApplication()
        targetInput = focusedTextInserter.captureTarget()
        appState.lastError = nil
        appState.setDebugMessage("Requesting microphone permission")
        AppLogger.log(
            "startDictation: requesting microphone permission, " +
            "targetApp=\(targetApplication?.bundleIdentifier ?? "unknown"), " +
            "targetInput=\(targetInput?.debugDescription ?? "none")"
        )

        let microphoneState = await microphonePermissionManager.requestIfNeeded()
        AppLogger.log("startDictation: microphone permission=\(String(describing: microphoneState))")
        guard microphoneState == .authorized else {
            appState.setError(.microphonePermissionRequired)
            appState.setDebugMessage("Microphone permission denied")
            return
        }

        do {
            appState.setDebugMessage("Starting recorder")
            try await audioRecorder.startRecording()
            appState.update(for: .recording)
            appState.setDebugMessage("Recorder started")
            AppLogger.log("startDictation: recorder started")
            startRecordingTimeout()
        } catch AudioSessionError.invalidInputFormat {
            appState.setError(.invalidAudioInput)
            appState.setDebugMessage("Invalid audio input format")
            AppLogger.log("startDictation: invalid audio input format")
        } catch {
            appState.setError(.noRecordedAudio)
            appState.setDebugMessage("Recorder failed: \(error.localizedDescription)")
            AppLogger.log("startDictation: recorder failed \(error.localizedDescription)")
        }
    }

    private func startRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.maximumRecordingDuration))
            guard !Task.isCancelled, let self else { return }
            await self.stopDictationAfterReachingTimeLimit()
        }
    }

    private func cancelRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
    }

    private func stopDictationAfterReachingTimeLimit() async {
        guard appState.dictationState == .recording else { return }

        AppLogger.log("stopDictation: reached the \(Int(Self.maximumRecordingDuration))s recording limit")
        appState.setDebugMessage("Reached the recording time limit; transcribing what was captured")
        await stopDictation()
    }

    /// Ends the session without inserting anything and, critically, without touching the
    /// clipboard — overwriting it with an empty string would destroy whatever the user had copied.
    private func finishWithoutInserting(statusText: String, debugMessage: String) {
        appState.update(for: .idle)
        appState.statusText = statusText
        appState.setDebugMessage(debugMessage)
        AppLogger.log("stopDictation: \(debugMessage)")
    }

    private func stopDictation() async {
        cancelRecordingTimeout()
        appState.update(for: .transcribing)
        appState.setDebugMessage("Stopping recorder")
        AppLogger.log("stopDictation: stopping recorder")

        do {
            let clip = try await audioRecorder.stopRecording()
            // Runs on every exit from this scope, so a failed transcription cannot leak the audio.
            defer { clip.deleteFile() }
            AppLogger.log("stopDictation: clip recorded at \(clip.fileURL.path)")

            if let duration = clip.duration, duration < Self.minimumClipDuration {
                finishWithoutInserting(
                    statusText: "Too short, nothing captured",
                    debugMessage: "Clip was \(String(format: "%.2f", duration))s, below the \(Self.minimumClipDuration)s minimum; skipped transcription"
                )
                return
            }
            let recognitionLanguage = appState.selectedRecognitionLanguage
            let chineseScriptPreference = appState.selectedChineseScriptPreference
            appState.setDebugMessage("Running WhisperKit (\(recognitionLanguage.statusDescription))")
            let transcript = try await transcriptionEngine.transcribe(
                clip,
                language: recognitionLanguage,
                chineseScriptPreference: chineseScriptPreference
            )
            guard transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                finishWithoutInserting(
                    statusText: "Nothing to insert",
                    debugMessage: "Transcript was empty after cleanup; clipboard left untouched"
                )
                return
            }

            appState.setTranscriptPreview(transcript.text)
            appState.update(for: .inserting)
            AppLogger.log("stopDictation: transcript length=\(transcript.text.count)")
            let insertOutcome = try insert(transcript.text)
            appState.update(for: .idle)
            appState.statusText = insertOutcome == .usedSelectedMode
                ? appState.selectedSuccessStatusMode.statusText
                : insertOutcome.statusText
            appState.setDebugMessage(insertOutcome.debugMessage)
            AppLogger.log("stopDictation: transcript copied or inserted")
        } catch let error as DictationError {
            appState.setError(error)
            appState.setDebugMessage("Dictation error: \(error.userMessage)")
            AppLogger.log("stopDictation: dictation error \(error.userMessage)")
        } catch let error as TranscriptionError {
            appState.setError(.transcriptionFailed(String(describing: error)))
            appState.setDebugMessage("Transcription error")
            AppLogger.log("stopDictation: transcription error \(String(describing: error))")
        } catch let error as InsertionError {
            switch error {
            case .notTrusted:
                appState.setError(.accessibilityPermissionRequired)
                appState.setDebugMessage("Accessibility permission required")
                AppLogger.log("stopDictation: accessibility permission required")
            default:
                appState.setError(.insertionFailed(String(describing: error)))
                appState.setDebugMessage("Insertion error")
                AppLogger.log("stopDictation: insertion error \(String(describing: error))")
            }
        } catch {
            appState.setError(.transcriptionFailed(error.localizedDescription))
            appState.setDebugMessage("Unexpected error")
            AppLogger.log("stopDictation: unexpected error \(error.localizedDescription)")
        }
    }

    private func insert(_ text: String) throws -> InsertOutcome {
        switch appState.selectedSuccessStatusMode {
        case .both:
            reactivateTargetApplicationIfNeeded()
            try clipboardStore.setText(text)
            AppLogger.log("insert: latest transcript synced to clipboard")

            guard accessibilityPermissionManager.isTrusted() else {
                accessibilityPermissionManager.promptIfNeeded()
                throw InsertionError.notTrusted
            }

            do {
                try insertIntoCapturedTargetOrCurrent(text)
                return .usedSelectedMode
            } catch InsertionError.capturedTargetUnavailable {
                AppLogger.log("insert: original input changed, keeping transcript in clipboard instead of inserting elsewhere")
                return .copiedBecauseTargetChanged
            } catch {
                AppLogger.log("insert: direct accessibility insert failed, falling back to paste")
                try fallbackTextInserter.paste(text, preserveClipboard: false)
                return .usedSelectedMode
            }
        case .transcriptCopied:
            try clipboardStore.setText(text)
            AppLogger.log("insert: transcript copied only")
            return .usedSelectedMode
        case .transcriptInserted:
            reactivateTargetApplicationIfNeeded()

            guard accessibilityPermissionManager.isTrusted() else {
                accessibilityPermissionManager.promptIfNeeded()
                throw InsertionError.notTrusted
            }

            AppLogger.log("insert: transcript inserted only")
            do {
                try insertIntoCapturedTargetOrCurrent(text)
                return .usedSelectedMode
            } catch InsertionError.capturedTargetUnavailable {
                AppLogger.log("insert: original input changed in insert-only mode, copying transcript instead of inserting into a different field")
                try clipboardStore.setText(text)
                return .copiedBecauseTargetChanged
            } catch {
                AppLogger.log("insert: direct accessibility insert failed in insert-only mode, falling back to paste")
                try fallbackTextInserter.paste(text, preserveClipboard: true)
                return .usedSelectedMode
            }
        }
    }

    private func insertIntoCapturedTargetOrCurrent(_ text: String) throws {
        if let targetInput {
            do {
                AppLogger.log("insert: trying captured input target \(targetInput.debugDescription)")
                try focusedTextInserter.insert(text, into: targetInput)
                return
            } catch {
                AppLogger.log("insert: captured input target failed, refusing to redirect into a different focused field")
                throw InsertionError.capturedTargetUnavailable
            }
        }

        try focusedTextInserter.insert(text)
    }

    private func captureTargetApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    private func reactivateTargetApplicationIfNeeded() {
        guard let targetApplication,
              targetApplication != NSRunningApplication.current else {
            return
        }

        AppLogger.log("insert: reactivating target app \(targetApplication.bundleIdentifier ?? "unknown")")
        targetApplication.activate()

        let timeout = Date().addingTimeInterval(0.6)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != targetApplication.processIdentifier,
              Date() < timeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
    }
}
