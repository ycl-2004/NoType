import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let appState: AppState
    private let coordinator: DictationCoordinator
    private let statusItem: NSStatusItem

    init(appState: AppState, coordinator: DictationCoordinator) {
        self.appState = appState
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        appState.onChange = { [weak self] in
            self?.refreshMenu()
        }
        configureStatusItem()
        refreshMenu()
    }

    func refreshMenu() {
        guard let button = statusItem.button else { return }
        updateStatusButton(button)

        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "Status: \(appState.statusText)", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        if let transcriptPreview = appState.lastTranscriptPreview {
            menu.addItem(NSMenuItem(title: "Last Transcript:", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: transcriptPreview, action: nil, keyEquivalent: ""))
        }

        if let lastDebugMessage = appState.lastDebugMessage {
            menu.addItem(NSMenuItem(title: "Debug:", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: lastDebugMessage, action: nil, keyEquivalent: ""))
        }

        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(handleToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let languageMenuItem = NSMenuItem(title: "Recognition: \(appState.selectedRecognitionLanguage.menuTitle)", action: nil, keyEquivalent: "")
        languageMenuItem.submenu = recognitionLanguageMenu()
        menu.addItem(languageMenuItem)

        let successStatusMenuItem = NSMenuItem(title: "Success Status: \(appState.selectedSuccessStatusMode.menuTitle)", action: nil, keyEquivalent: "")
        successStatusMenuItem.submenu = successStatusModeMenu()
        menu.addItem(successStatusMenuItem)

        let shortcutItem = NSMenuItem(title: "Shortcut: Command + Shift + H", action: nil, keyEquivalent: "")
        menu.addItem(shortcutItem)

        let logPathItem = NSMenuItem(title: "Log: \(AppLogger.debugLogURL.path)", action: nil, keyEquivalent: "")
        menu.addItem(logPathItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit noType", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    private var toggleTitle: String {
        switch appState.dictationState {
        case .recording:
            "Stop Dictation"
        default:
            "Start Dictation"
        }
    }

    private var statusSymbolName: String {
        switch appState.dictationState {
        case .idle:
            "mic"
        case .recording:
            "mic.fill"
        case .transcribing:
            "waveform"
        case .inserting:
            "arrow.right.circle.fill"
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    private var statusToolTip: String {
        "noType: \(appState.statusText)"
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.title = ""
        updateStatusButton(button)
    }

    private func updateStatusButton(_ button: NSStatusBarButton) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(systemSymbolName: statusSymbolName, accessibilityDescription: "noType")
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(configuration)
        button.title = ""
        button.toolTip = statusToolTip
    }

    private func recognitionLanguageMenu() -> NSMenu {
        let menu = NSMenu()

        for language in DictationRecognitionLanguage.allCases {
            let item = NSMenuItem(
                title: language.menuTitle,
                action: #selector(handleRecognitionLanguageSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = appState.selectedRecognitionLanguage == language ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func successStatusModeMenu() -> NSMenu {
        let menu = NSMenu()

        for mode in DictationSuccessStatusMode.allCases {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(handleSuccessStatusModeSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = appState.selectedSuccessStatusMode == mode ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    @objc
    private func handleToggle() {
        Task { [coordinator] in
            await coordinator.toggleDictation()
        }
    }

    @objc
    private func handleRecognitionLanguageSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = DictationRecognitionLanguage(rawValue: rawValue) else {
            return
        }

        appState.setRecognitionLanguage(language)
        appState.setDebugMessage("Recognition language set to \(language.statusDescription)")
    }

    @objc
    private func handleSuccessStatusModeSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = DictationSuccessStatusMode(rawValue: rawValue) else {
            return
        }

        appState.setSuccessStatusMode(mode)
        appState.setDebugMessage("Success status set to \(mode.menuTitle)")
    }

    @objc
    private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
