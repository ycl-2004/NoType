import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState!
    private(set) var coordinator: DictationCoordinator!
    private var menuBarController: MenuBarController?
    private var hotkeyManager: GlobalHotkeyManager?
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
        hotkeyManager = GlobalHotkeyManager { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.toggleDictation()
            }
        }
        hotkeyManager?.register()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregister()
    }
}
