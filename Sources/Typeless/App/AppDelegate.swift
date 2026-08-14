import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState!
    private(set) var coordinator: DictationCoordinator!
    private var menuBarController: MenuBarController?
    private var dictationHotkeyManager: GlobalHotkeyManager?
    private var dictationDoubleTapMonitor: ModifierDoubleTapMonitor?
    private var recognitionModeHotkeyManager: GlobalHotkeyManager?
    private var registeredDictationShortcut: DictationShortcutChoice?
    private var registeredRecognitionModeShortcut: RecognitionModeShortcutChoice?
    private let microphonePermissionManager = MicrophonePermissionManager()
    private let accessibilityPermissionManager = AccessibilityPermissionManager()
    private let permissionSettingsOpener = SystemSettingsOpener()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        appState.onChange = { [weak self] in
            existingOnChange?()
            self?.refreshShortcutRegistration()
        }
        refreshShortcutRegistration()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        dictationHotkeyManager?.unregister()
        dictationDoubleTapMonitor?.stop()
        recognitionModeHotkeyManager?.unregister()
    }

    private func refreshShortcutRegistration() {
        refreshDictationShortcutRegistration()
        refreshRecognitionModeShortcutRegistration()
    }

    private func refreshDictationShortcutRegistration() {
        let selectedShortcut = appState.selectedDictationShortcut
        guard registeredDictationShortcut != selectedShortcut else { return }

        dictationHotkeyManager?.unregister()
        dictationHotkeyManager = nil
        dictationDoubleTapMonitor?.stop()
        dictationDoubleTapMonitor = nil
        registeredDictationShortcut = selectedShortcut

        let action: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.toggleDictation()
            }
        }

        if let modifierKey = selectedShortcut.doubleTapKey {
            let monitor = ModifierDoubleTapMonitor(modifierKey: modifierKey, onDoubleTap: action)
            if monitor.start() {
                dictationDoubleTapMonitor = monitor
            } else {
                appState.setDebugMessage("Failed to enable \(selectedShortcut.menuTitle)")
            }
            return
        }

        if let keyCombination = selectedShortcut.keyCombination {
            let manager = GlobalHotkeyManager(
                hotkeyKind: .dictation,
                keyCombination: keyCombination,
                onHotkeyPressed: action
            )
            if manager.register() {
                dictationHotkeyManager = manager
            } else {
                appState.setDebugMessage("Failed to enable \(selectedShortcut.menuTitle)")
            }
        }
    }

    private func refreshRecognitionModeShortcutRegistration() {
        let selectedShortcut = appState.selectedRecognitionModeShortcut
        guard registeredRecognitionModeShortcut != selectedShortcut else { return }

        recognitionModeHotkeyManager?.unregister()
        recognitionModeHotkeyManager = nil
        registeredRecognitionModeShortcut = selectedShortcut

        guard let keyCombination = selectedShortcut.keyCombination else { return }
        let manager = GlobalHotkeyManager(
            hotkeyKind: .recognitionModeCycle,
            keyCombination: keyCombination
        ) { [weak self] in
            guard let self else { return }
            let nextLanguage = self.appState.selectedRecognitionLanguage.nextCycleValue
            self.appState.setRecognitionLanguage(nextLanguage)
            self.appState.setDebugMessage("Recognition language set to \(nextLanguage.statusDescription)")
        }
        if manager.register() {
            recognitionModeHotkeyManager = manager
        } else {
            appState.setDebugMessage("Failed to enable \(selectedShortcut.menuTitle)")
        }
    }
}
