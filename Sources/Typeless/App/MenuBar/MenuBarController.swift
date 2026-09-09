import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let appState: AppState
    private let coordinator: DictationCoordinator
    private let microphonePermissionManager: MicrophonePermissionManaging
    private let accessibilityPermissionManager: AccessibilityPermissionManaging
    private let permissionSettingsOpener: PermissionSettingsOpening
    private let localModelManager: LocalModelRemoving
    private let statusItem: NSStatusItem

    init(
        appState: AppState,
        coordinator: DictationCoordinator,
        microphonePermissionManager: MicrophonePermissionManaging = MicrophonePermissionManager(),
        accessibilityPermissionManager: AccessibilityPermissionManaging = AccessibilityPermissionManager(),
        permissionSettingsOpener: PermissionSettingsOpening = SystemSettingsOpener(),
        localModelManager: LocalModelRemoving = LocalModelManager()
    ) {
        self.appState = appState
        self.coordinator = coordinator
        self.microphonePermissionManager = microphonePermissionManager
        self.accessibilityPermissionManager = accessibilityPermissionManager
        self.permissionSettingsOpener = permissionSettingsOpener
        self.localModelManager = localModelManager
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
        statusItem.menu = makeMenu()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "Status: \(appState.statusText)", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(handleToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let languageMenuItem = NSMenuItem(title: "Recognition: \(appState.selectedRecognitionLanguage.menuTitle)", action: nil, keyEquivalent: "")
        languageMenuItem.submenu = recognitionLanguageMenu()
        menu.addItem(languageMenuItem)

        let engineMenuItem = NSMenuItem(
            title: "Engine: \(engineMenuSummary)",
            action: nil,
            keyEquivalent: ""
        )
        engineMenuItem.submenu = transcriptionEngineMenu()
        menu.addItem(engineMenuItem)

        let chineseScriptMenuItem = NSMenuItem(
            title: "Chinese Script: \(appState.selectedChineseScriptPreference.menuTitle)",
            action: nil,
            keyEquivalent: ""
        )
        chineseScriptMenuItem.submenu = chineseScriptPreferenceMenu()
        menu.addItem(chineseScriptMenuItem)

        let successStatusMenuItem = NSMenuItem(title: "Success Status: \(appState.selectedSuccessStatusMode.menuTitle)", action: nil, keyEquivalent: "")
        successStatusMenuItem.submenu = successStatusModeMenu()
        menu.addItem(successStatusMenuItem)

        let shortcutsMenuItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
        shortcutsMenuItem.submenu = shortcutsMenu()
        menu.addItem(shortcutsMenuItem)

        let permissionsMenuItem = NSMenuItem(title: "Permissions", action: nil, keyEquivalent: "")
        permissionsMenuItem.submenu = permissionsMenu()
        menu.addItem(permissionsMenuItem)

        let diagnosticsMenuItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        diagnosticsMenuItem.submenu = diagnosticsMenu()
        menu.addItem(diagnosticsMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NoType", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
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
        "NoType: \(appState.statusText)"
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.title = ""
        updateStatusButton(button)
    }

    private func updateStatusButton(_ button: NSStatusBarButton) {
        let configuration = MenuBarIconRenderer.Configuration(
            state: appState.dictationState,
            recognitionLanguage: appState.selectedRecognitionLanguage,
            chineseScriptPreference: appState.selectedChineseScriptPreference
        )
        button.image = MenuBarIconRenderer.makeImage(for: configuration) ?? MenuBarIconRenderer.baseSymbolImage(for: appState.dictationState)
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

    /// Auto silently routes away from macOS Speech because that engine cannot detect the spoken
    /// language, so the menu says so rather than showing a preference the current mode is not
    /// honouring.
    private var engineMenuSummary: String {
        let selected = appState.selectedTranscriptionEngine
        let effective = selected.resolvedEngine(for: appState.selectedRecognitionLanguage)
        guard effective != selected else { return selected.menuTitle }
        return "\(selected.menuTitle) → \(effective.menuTitle)"
    }

    func transcriptionEngineMenu() -> NSMenu {
        let menu = NSMenu()

        for engine in TranscriptionEngineChoice.allCases {
            let item = NSMenuItem(
                title: engine.menuTitle,
                action: #selector(handleTranscriptionEngineSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = engine.rawValue
            item.state = appState.selectedTranscriptionEngine == engine ? .on : .off
            // Offering macOS Speech on a system without it would be a setting that does nothing.
            item.isEnabled = engine != .appleSpeech || TranscriptionEngineChoice.isAppleSpeechAvailable
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let note = TranscriptionEngineChoice.isAppleSpeechAvailable
            ? "Auto uses a multilingual local model"
            : "Needs macOS 26 for macOS Speech"
        menu.addItem(NSMenuItem(title: note, action: nil, keyEquivalent: ""))

        menu.addItem(.separator())
        let manageModelsItem = NSMenuItem(title: "Manage Downloaded Models", action: nil, keyEquivalent: "")
        manageModelsItem.submenu = downloadedModelMenu()
        menu.addItem(manageModelsItem)

        return menu
    }

    private func downloadedModelMenu() -> NSMenu {
        let menu = NSMenu()
        let canRemove = appState.dictationState == .idle

        for model in DownloadedLocalModel.allCases {
            let installed = localModelManager.isInstalled(model)
            let item = NSMenuItem(
                title: installed ? "Delete \(model.menuTitle)" : "\(model.menuTitle) (not installed)",
                action: installed ? #selector(handleDeleteDownloadedModel(_:)) : nil,
                keyEquivalent: ""
            )
            item.target = installed ? self : nil
            item.representedObject = model.rawValue
            item.isEnabled = installed && canRemove
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let locationItem = NSMenuItem(
            title: "Only NoType downloads are removed",
            action: nil,
            keyEquivalent: ""
        )
        locationItem.isEnabled = false
        menu.addItem(locationItem)

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

    private func chineseScriptPreferenceMenu() -> NSMenu {
        let menu = NSMenu()

        for preference in ChineseScriptPreference.allCases {
            let item = NSMenuItem(
                title: preference.menuTitle,
                action: #selector(handleChineseScriptPreferenceSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preference.rawValue
            item.state = appState.selectedChineseScriptPreference == preference ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func permissionsMenu() -> NSMenu {
        let menu = NSMenu()

        let accessibilityTrusted = accessibilityPermissionManager.isTrusted()
        let microphoneState = microphonePermissionManager.currentState()

        let accessibilityStatus = accessibilityTrusted ? "Granted" : "Required"
        let microphoneStatus = microphoneState == .authorized ? "Granted" : "Required"

        menu.addItem(NSMenuItem(title: "Accessibility: \(accessibilityStatus)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Microphone: \(microphoneStatus)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(handleOpenAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let microphoneItem = NSMenuItem(
            title: "Open Microphone Settings",
            action: #selector(handleOpenMicrophoneSettings),
            keyEquivalent: ""
        )
        microphoneItem.target = self
        menu.addItem(microphoneItem)

        return menu
    }

    func shortcutsMenu() -> NSMenu {
        let menu = NSMenu()

        let dictationItem = NSMenuItem(
            title: "Dictation: \(appState.dictationShortcutMenuTitle)",
            action: nil,
            keyEquivalent: ""
        )
        dictationItem.submenu = dictationShortcutMenu()
        menu.addItem(dictationItem)

        let recognitionModeItem = NSMenuItem(
            title: "Recognition Mode: \(appState.recognitionModeShortcutMenuTitle)",
            action: nil,
            keyEquivalent: ""
        )
        recognitionModeItem.submenu = recognitionModeShortcutMenu()
        menu.addItem(recognitionModeItem)

        return menu
    }

    private func dictationShortcutMenu() -> NSMenu {
        let menu = NSMenu()
        addCurrentShortcutItems(appState.dictationShortcuts, to: menu, actionIdentifier: "dictation")

        let addItem = NSMenuItem(
            title: "Add Shortcut…",
            action: #selector(handleAddDictationShortcut),
            keyEquivalent: ""
        )
        addItem.target = self
        menu.addItem(addItem)

        if appState.dictationShortcuts.isEmpty == false {
            let disableItem = NSMenuItem(
                title: "Disable All",
                action: #selector(handleDisableDictationShortcuts),
                keyEquivalent: ""
            )
            disableItem.target = self
            menu.addItem(disableItem)
        }

        return menu
    }

    private func recognitionModeShortcutMenu() -> NSMenu {
        let menu = NSMenu()
        addCurrentShortcutItems(appState.recognitionModeShortcuts, to: menu, actionIdentifier: "recognition")

        let addItem = NSMenuItem(
            title: "Add Shortcut…",
            action: #selector(handleAddRecognitionModeShortcut),
            keyEquivalent: ""
        )
        addItem.target = self
        menu.addItem(addItem)

        if appState.recognitionModeShortcuts.isEmpty == false {
            let disableItem = NSMenuItem(
                title: "Disable All",
                action: #selector(handleDisableRecognitionModeShortcuts),
                keyEquivalent: ""
            )
            disableItem.target = self
            menu.addItem(disableItem)
        }

        return menu
    }

    private func addCurrentShortcutItems(
        _ shortcuts: [ShortcutBinding],
        to menu: NSMenu,
        actionIdentifier: String
    ) {
        if shortcuts.isEmpty {
            let emptyItem = NSMenuItem(title: "No shortcuts set", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, shortcut) in shortcuts.enumerated() {
                let item = NSMenuItem(title: shortcut.menuTitle, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.state = .on
                item.toolTip = "Shortcut \(index + 1)"
                menu.addItem(item)
            }
            menu.addItem(.separator())
            for (index, shortcut) in shortcuts.enumerated() {
                let item = NSMenuItem(
                    title: "Remove \(shortcut.menuTitle)",
                    action: #selector(handleRemoveShortcut(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.representedObject = actionIdentifier
                menu.addItem(item)
            }
        }
    }

    func diagnosticsMenu() -> NSMenu {
        let menu = NSMenu()

        let readiness = appState.localModelReadiness
        let modelStatusItem = NSMenuItem(
            title: "Speech Model: \(readiness.menuTitle)",
            action: nil,
            keyEquivalent: ""
        )
        modelStatusItem.isEnabled = false
        modelStatusItem.image = NSImage(
            systemSymbolName: readiness.symbolName,
            accessibilityDescription: "Speech model \(readiness.menuTitle)"
        )
        menu.addItem(modelStatusItem)

        let readinessDetailItem = NSMenuItem(title: readiness.detailText, action: nil, keyEquivalent: "")
        readinessDetailItem.isEnabled = false
        readinessDetailItem.indentationLevel = 1
        menu.addItem(readinessDetailItem)

        if let reason = readiness.failureReason {
            let oneLineReason = reason.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            let isTruncated = oneLineReason.count > 110
            let reasonItem = NSMenuItem(
                title: "Details: \(oneLineReason.prefix(110))\(isTruncated ? "…" : "")",
                action: nil,
                keyEquivalent: ""
            )
            reasonItem.isEnabled = false
            reasonItem.indentationLevel = 1
            reasonItem.toolTip = reason
            menu.addItem(reasonItem)

            let retryItem = NSMenuItem(
                title: "Try Again",
                action: #selector(handleRetryModelPreparation),
                keyEquivalent: ""
            )
            retryItem.target = self
            menu.addItem(retryItem)
        }

        menu.addItem(.separator())

        if let lastDebugMessage = appState.lastDebugMessage {
            let debugItem = NSMenuItem(title: "Recent Activity: \(lastDebugMessage)", action: nil, keyEquivalent: "")
            debugItem.isEnabled = false
            menu.addItem(debugItem)
            menu.addItem(.separator())
        }

        let openLogItem = NSMenuItem(
            title: "View Debug Log",
            action: #selector(handleOpenDebugLog),
            keyEquivalent: ""
        )
        openLogItem.target = self
        menu.addItem(openLogItem)

        let logPathItem = NSMenuItem(title: "Log file: notype-debug.log", action: nil, keyEquivalent: "")
        logPathItem.isEnabled = false
        logPathItem.toolTip = AppLogger.debugLogURL.path
        menu.addItem(logPathItem)

        return menu
    }

    @objc
    private func handleRetryModelPreparation() {
        Task { [coordinator] in
            await coordinator.prepareForFirstDictation()
        }
    }

    @objc
    private func handleDeleteDownloadedModel(_ sender: NSMenuItem) {
        guard appState.dictationState == .idle,
              let rawValue = sender.representedObject as? String,
              let model = DownloadedLocalModel(rawValue: rawValue),
              localModelManager.isInstalled(model) else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Delete \(model.menuTitle)?"
        alert.informativeText = "This removes \(model.locationDescription). macOS Speech assets are not affected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Model")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let removed = try localModelManager.remove(model)
            guard removed else { return }
            appState.setLocalModelReadiness(.waiting)
            appState.setDebugMessage("Deleted \(model.menuTitle) from the NoType model folders")
        } catch {
            let errorAlert = NSAlert(error: error)
            errorAlert.messageText = "Could not delete \(model.menuTitle)"
            errorAlert.informativeText = "The model files were left in place."
            errorAlert.runModal()
        }
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
    private func handleTranscriptionEngineSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let engine = TranscriptionEngineChoice(rawValue: rawValue) else {
            return
        }

        appState.setTranscriptionEngine(engine)
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
    private func handleChineseScriptPreferenceSelection(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preference = ChineseScriptPreference(rawValue: rawValue) else {
            return
        }

        appState.setChineseScriptPreference(preference)
        appState.setDebugMessage("Chinese script set to \(preference.statusDescription)")
    }

    @objc
    private func handleAddDictationShortcut() {
        guard let shortcut = recordShortcut() else { return }
        guard canAdd(shortcut, to: "dictation") else { return }
        appState.addDictationShortcut(shortcut)
        appState.setDebugMessage("Dictation shortcut added: \(shortcut.menuTitle)")
    }

    @objc
    private func handleAddRecognitionModeShortcut() {
        guard let shortcut = recordShortcut() else { return }
        guard canAdd(shortcut, to: "recognition") else { return }
        appState.addRecognitionModeShortcut(shortcut)
        appState.setDebugMessage("Recognition mode shortcut added: \(shortcut.menuTitle)")
    }

    @objc
    private func handleRemoveShortcut(_ sender: NSMenuItem) {
        guard let actionIdentifier = sender.representedObject as? String else { return }
        if actionIdentifier == "dictation" {
            appState.removeDictationShortcut(at: sender.tag)
            appState.setDebugMessage("Dictation shortcut removed")
        } else if actionIdentifier == "recognition" {
            appState.removeRecognitionModeShortcut(at: sender.tag)
            appState.setDebugMessage("Recognition mode shortcut removed")
        }
    }

    @objc
    private func handleDisableDictationShortcuts() {
        appState.disableDictationShortcuts()
        appState.setDebugMessage("Dictation shortcuts disabled")
    }

    @objc
    private func handleDisableRecognitionModeShortcuts() {
        appState.disableRecognitionModeShortcuts()
        appState.setDebugMessage("Recognition mode shortcuts disabled")
    }

    private func recordShortcut() -> ShortcutBinding? {
        guard let shortcut = ShortcutRecorder.record() else { return nil }
        if shortcut.isModifierOnly || shortcut.modifiers.isEmpty == false {
            return shortcut
        } else {
            let alert = NSAlert()
            alert.messageText = "Use \(shortcut.menuTitle) as a shortcut?"
            alert.informativeText = "A regular key without a modifier can interfere with typing in other apps."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Use Anyway")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return nil }
        }
        return shortcut
    }

    private func canAdd(_ shortcut: ShortcutBinding, to actionIdentifier: String) -> Bool {
        let currentShortcuts = actionIdentifier == "dictation"
            ? appState.dictationShortcuts
            : appState.recognitionModeShortcuts
        guard currentShortcuts.contains(where: { $0.conflicts(with: shortcut) }) == false else {
            showShortcutConflict(message: "That shortcut is already assigned to this action.")
            return false
        }

        let otherShortcuts = actionIdentifier == "dictation"
            ? appState.recognitionModeShortcuts
            : appState.dictationShortcuts
        guard otherShortcuts.contains(where: { $0.conflicts(with: shortcut) }) == false else {
            showShortcutConflict(message: "That shortcut is already assigned to the other NoType action.")
            return false
        }
        return true
    }

    private func showShortcutConflict(message: String) {
        let alert = NSAlert()
        alert.messageText = "Shortcut Already Used"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func handleOpenDebugLog() {
        NSWorkspace.shared.open(AppLogger.debugLogURL)
        appState.setDebugMessage("Opened debug log")
    }

    @objc
    private func handleOpenAccessibilitySettings() {
        permissionSettingsOpener.openSettings(for: .accessibility)
        appState.setDebugMessage("Opened Accessibility settings")
    }

    @objc
    private func handleOpenMicrophoneSettings() {
        permissionSettingsOpener.openSettings(for: .microphone)
        appState.setDebugMessage("Opened Microphone settings")
    }

    @objc
    private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
