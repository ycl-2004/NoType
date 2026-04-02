import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState!
    private(set) var coordinator: DictationCoordinator!
    private var menuBarController: MenuBarController?
    private var dictationHotkeyManager: GlobalHotkeyManager?
    private var recognitionModeHotkeyManager: GlobalHotkeyManager?
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
            self?.refreshHotkeyRegistration()
        }
        refreshHotkeyRegistration()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        dictationHotkeyManager?.unregister()
        recognitionModeHotkeyManager?.unregister()
    }

    private func refreshHotkeyRegistration() {
        if appState.isDictationShortcutEnabled {
            if dictationHotkeyManager == nil {
                dictationHotkeyManager = GlobalHotkeyManager(
                    hotkeyKind: .dictation,
                    keyCombination: .defaultDictationShortcut
                ) { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.coordinator.toggleDictation()
                    }
                }
                dictationHotkeyManager?.register()
            }
        } else {
            dictationHotkeyManager?.unregister()
            dictationHotkeyManager = nil
        }

        if appState.isRecognitionModeShortcutEnabled {
            if recognitionModeHotkeyManager == nil {
                recognitionModeHotkeyManager = GlobalHotkeyManager(
                    hotkeyKind: .recognitionModeCycle,
                    keyCombination: .recognitionModeShortcut
                ) { [weak self] in
                    guard let self else { return }
                    let nextLanguage = self.appState.selectedRecognitionLanguage.nextCycleValue
                    self.appState.setRecognitionLanguage(nextLanguage)
                    self.appState.setDebugMessage("Recognition language set to \(nextLanguage.statusDescription)")
                }
                recognitionModeHotkeyManager?.register()
            }
        } else {
            recognitionModeHotkeyManager?.unregister()
            recognitionModeHotkeyManager = nil
        }
    }
}
