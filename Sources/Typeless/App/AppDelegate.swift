import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState!
    private(set) var coordinator: DictationCoordinator!
    private var menuBarController: MenuBarController?
    private var voiceOverlayController: VoiceOverlayController?
    private var dictationShortcutMonitor: ShortcutMonitor?
    private var recognitionModeShortcutMonitor: ShortcutMonitor?
    private var registeredDictationShortcuts: [ShortcutBinding]?
    private var registeredRecognitionModeShortcuts: [ShortcutBinding]?
    private var shortcutListeningActivity: NSObjectProtocol?
    private var escapeKeyInterceptor: EscapeKeyInterceptor?
    private let microphonePermissionManager = MicrophonePermissionManager()
    private let accessibilityPermissionManager = AccessibilityPermissionManager()
    private let permissionSettingsOpener = SystemSettingsOpener()

    func applicationDidFinishLaunching(_ notification: Notification) {
        shortcutListeningActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Listening for global keyboard shortcuts"
        )

        appState = AppState()
        coordinator = DictationCoordinator(
            appState: appState,
            microphonePermissionManager: microphonePermissionManager,
            accessibilityPermissionManager: accessibilityPermissionManager
        )
        menuBarController = MenuBarController(
            appState: appState,
            coordinator: coordinator,
            microphonePermissionManager: microphonePermissionManager,
            accessibilityPermissionManager: accessibilityPermissionManager,
            permissionSettingsOpener: permissionSettingsOpener
        )
        let existingOnChange = appState.onChange
        escapeKeyInterceptor = EscapeKeyInterceptor { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.cancelDictation()
            }
        }
        appState.onChange = { [weak self] in
            existingOnChange?()
            self?.refreshShortcutRegistration()
            self?.refreshEscapeInterception()
        }
        refreshShortcutRegistration()
        NSApp.setActivationPolicy(.accessory)
        voiceOverlayController = VoiceOverlayController(appState: appState)

        AudioRecorder.removeOrphanedClips()
        Task { [coordinator] in
            await coordinator?.prepareForFirstDictation()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.releaseTranscriptionResources()
        escapeKeyInterceptor?.stop()
        voiceOverlayController?.close()
        dictationShortcutMonitor?.stop()
        recognitionModeShortcutMonitor?.stop()
        if let shortcutListeningActivity {
            ProcessInfo.processInfo.endActivity(shortcutListeningActivity)
            self.shortcutListeningActivity = nil
        }
    }

    /// Escape cancels only an active session; at any other time it belongs to the focused app.
    private func refreshEscapeInterception() {
        guard let escapeKeyInterceptor else { return }
        switch appState.dictationState {
        case .recording, .transcribing:
            guard escapeKeyInterceptor.isActive == false else { return }
            if escapeKeyInterceptor.start() == false {
                AppLogger.log("Escape cancel unavailable: macOS refused the key event tap (Accessibility permission?)")
            }
        case .idle, .inserting, .error:
            escapeKeyInterceptor.stop()
        }
    }

    private func refreshShortcutRegistration() {
        refreshDictationShortcutRegistration()
        refreshRecognitionModeShortcutRegistration()
    }

    private func refreshDictationShortcutRegistration() {
        let selectedShortcuts = appState.dictationShortcuts
        guard registeredDictationShortcuts != selectedShortcuts else { return }

        dictationShortcutMonitor?.stop()
        dictationShortcutMonitor = nil
        registeredDictationShortcuts = selectedShortcuts

        let action: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.toggleDictation()
            }
        }

        guard selectedShortcuts.isEmpty == false else { return }

        let monitor = ShortcutMonitor(bindings: selectedShortcuts, onShortcutPressed: action)
        if monitor.start() {
            dictationShortcutMonitor = monitor
        } else {
            appState.setDebugMessage("Could not enable the dictation shortcuts")
        }
    }

    private func refreshRecognitionModeShortcutRegistration() {
        let selectedShortcuts = appState.recognitionModeShortcuts
        guard registeredRecognitionModeShortcuts != selectedShortcuts else { return }

        recognitionModeShortcutMonitor?.stop()
        recognitionModeShortcutMonitor = nil
        registeredRecognitionModeShortcuts = selectedShortcuts

        guard selectedShortcuts.isEmpty == false else { return }

        let monitor = ShortcutMonitor(bindings: selectedShortcuts) { [weak self] in
            guard let self else { return }
            let nextLanguage = self.appState.selectedRecognitionLanguage.nextCycleValue
            self.appState.setRecognitionLanguage(nextLanguage)
            self.appState.setDebugMessage("Recognition language set to \(nextLanguage.statusDescription)")
        }
        if monitor.start() {
            recognitionModeShortcutMonitor = monitor
        } else {
            appState.setDebugMessage("Could not enable the recognition mode shortcuts")
        }
    }
}
