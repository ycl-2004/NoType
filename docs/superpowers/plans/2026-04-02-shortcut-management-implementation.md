# Shortcut Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Shortcuts` submenu that lets users independently enable or disable the dictation shortcut and the recognition-mode shortcut.

**Architecture:** Extend app state with two persisted boolean settings, then replace the single-hotkey startup path with independently managed hotkey registrations for dictation and recognition-mode cycling. Keep the menu interaction lightweight by making each submenu row directly toggle its enabled state while immediately updating hotkey registration and visible menu labels.

**Tech Stack:** Swift, AppKit, Carbon hotkey APIs, Swift Testing, UserDefaults

---

## File Map

- Modify: `Sources/Typeless/App/AppState.swift`
  Responsibility: persist independent enabled-state settings for the dictation and recognition-mode shortcuts.
- Modify: `Sources/Typeless/App/AppDelegate.swift`
  Responsibility: manage two independent global hotkey registrations and keep them in sync with app state.
- Modify: `Sources/Typeless/Hotkey/GlobalHotkeyManager.swift`
  Responsibility: support multiple independent hotkey instances cleanly without conflicting event IDs.
- Modify: `Sources/Typeless/Hotkey/KeyCombination.swift`
  Responsibility: define the recognition-mode shortcut key combination alongside the existing dictation shortcut.
- Modify: `Sources/Typeless/App/MenuBar/MenuBarController.swift`
  Responsibility: replace the static shortcut text row with a `Shortcuts` submenu that directly toggles each shortcut.
- Modify: `Sources/Typeless/Domain/DictationRecognitionLanguage.swift`
  Responsibility: expose a helper for cycling to the next recognition mode.
- Modify: `Tests/TypelessTests/AppStateTests.swift`
  Responsibility: verify shortcut enable-state persistence.
- Create: `Tests/TypelessTests/GlobalHotkeyManagerTests.swift`
  Responsibility: verify independent hotkey identifiers or configuration behavior without requiring a real keyboard event.
- Modify: `Tests/TypelessTests/DictationCoordinatorTests.swift`
  Responsibility: only if lightweight helper extraction requires adjacent state verification.
- Create: `Tests/TypelessTests/ShortcutMenuTests.swift`
  Responsibility: verify submenu title formatting and toggle behavior at the menu/controller logic layer.

### Task 1: Add persisted shortcut settings

**Files:**
- Modify: `Sources/Typeless/App/AppState.swift`
- Modify: `Tests/TypelessTests/AppStateTests.swift`

- [ ] **Step 1: Write the failing test for default shortcut settings**

```swift
@Test
func defaultsShortcutTogglesToEnabled() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    defer { defaults.removePersistentDomain(forName: #function) }

    let appState = AppState(userDefaults: defaults)

    #expect(appState.isDictationShortcutEnabled == true)
    #expect(appState.isRecognitionModeShortcutEnabled == true)
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter defaultsShortcutTogglesToEnabled`
Expected: FAIL because those properties do not exist yet.

- [ ] **Step 3: Write the failing persistence test**

```swift
@Test
func loadsSavedShortcutToggleSettingsFromUserDefaults() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.set(false, forKey: "dictationShortcutEnabled")
    defaults.set(true, forKey: "recognitionModeShortcutEnabled")
    defer { defaults.removePersistentDomain(forName: #function) }

    let appState = AppState(userDefaults: defaults)

    #expect(appState.isDictationShortcutEnabled == false)
    #expect(appState.isRecognitionModeShortcutEnabled == true)
}
```

- [ ] **Step 4: Run the focused persistence test to verify it fails**

Run: `swift test --filter loadsSavedShortcutToggleSettingsFromUserDefaults`
Expected: FAIL before the settings are added.

- [ ] **Step 5: Add stored shortcut enable-state properties and setters**

```swift
@Published var isDictationShortcutEnabled: Bool {
    didSet {
        userDefaults.set(isDictationShortcutEnabled, forKey: DefaultsKey.dictationShortcutEnabled)
        onChange?()
    }
}

@Published var isRecognitionModeShortcutEnabled: Bool {
    didSet {
        userDefaults.set(isRecognitionModeShortcutEnabled, forKey: DefaultsKey.recognitionModeShortcutEnabled)
        onChange?()
    }
}
```

```swift
func setDictationShortcutEnabled(_ enabled: Bool) {
    guard isDictationShortcutEnabled != enabled else { return }
    isDictationShortcutEnabled = enabled
}

func setRecognitionModeShortcutEnabled(_ enabled: Bool) {
    guard isRecognitionModeShortcutEnabled != enabled else { return }
    isRecognitionModeShortcutEnabled = enabled
}
```

- [ ] **Step 6: Run the app-state test suite**

Run: `swift test --filter AppStateTests`
Expected: PASS

- [ ] **Step 7: Commit the settings layer**

```bash
git add Sources/Typeless/App/AppState.swift Tests/TypelessTests/AppStateTests.swift
git commit -m "feat: persist shortcut toggle settings"
```

### Task 2: Support two independent hotkeys

**Files:**
- Modify: `Sources/Typeless/Hotkey/KeyCombination.swift`
- Modify: `Sources/Typeless/Hotkey/GlobalHotkeyManager.swift`
- Create: `Tests/TypelessTests/GlobalHotkeyManagerTests.swift`

- [ ] **Step 1: Write the failing test for the recognition-mode shortcut definition**

```swift
@Test
func definesRecognitionModeShortcut() {
    #expect(KeyCombination.recognitionModeShortcut == KeyCombination(
        keyCode: UInt32(kVK_ANSI_Y),
        modifiers: UInt32(cmdKey | shiftKey)
    ))
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter definesRecognitionModeShortcut`
Expected: FAIL because the shortcut constant does not exist yet.

- [ ] **Step 3: Write the failing test for unique hotkey identifiers**

```swift
@Test
func hotkeyManagerUsesDistinctIdentifiersPerShortcut() {
    #expect(GlobalHotkeyManager.HotkeyKind.dictation.id != GlobalHotkeyManager.HotkeyKind.recognitionModeCycle.id)
}
```

- [ ] **Step 4: Run the focused identifier test to verify it fails**

Run: `swift test --filter hotkeyManagerUsesDistinctIdentifiersPerShortcut`
Expected: FAIL because the hotkey-kind model does not exist yet.

- [ ] **Step 5: Add the second key combination and hotkey kind model**

```swift
static let recognitionModeShortcut = KeyCombination(
    keyCode: UInt32(kVK_ANSI_Y),
    modifiers: UInt32(cmdKey | shiftKey)
)
```

```swift
enum HotkeyKind {
    case dictation
    case recognitionModeCycle

    var id: UInt32 { ... }
    var signature: FourCharCode { ... }
}
```

- [ ] **Step 6: Update `GlobalHotkeyManager` to accept a hotkey kind**

```swift
init(
    hotkeyKind: HotkeyKind,
    keyCombination: KeyCombination,
    onHotkeyPressed: @escaping @MainActor () -> Void
) { ... }
```

- [ ] **Step 7: Run the hotkey-focused tests**

Run: `swift test --filter GlobalHotkeyManagerTests`
Expected: PASS

- [ ] **Step 8: Commit the multi-hotkey support**

```bash
git add Sources/Typeless/Hotkey/KeyCombination.swift Sources/Typeless/Hotkey/GlobalHotkeyManager.swift Tests/TypelessTests/GlobalHotkeyManagerTests.swift
git commit -m "feat: support independent global hotkeys"
```

### Task 3: Add recognition-mode cycling behavior

**Files:**
- Modify: `Sources/Typeless/Domain/DictationRecognitionLanguage.swift`
- Create: `Tests/TypelessTests/ShortcutMenuTests.swift`

- [ ] **Step 1: Write the failing test for recognition-mode cycling**

```swift
@Test
func recognitionLanguageCyclesInApprovedOrder() {
    #expect(DictationRecognitionLanguage.mixed.nextCycleValue == .chinese)
    #expect(DictationRecognitionLanguage.chinese.nextCycleValue == .english)
    #expect(DictationRecognitionLanguage.english.nextCycleValue == .mixed)
}
```

- [ ] **Step 2: Run the focused cycling test to verify it fails**

Run: `swift test --filter recognitionLanguageCyclesInApprovedOrder`
Expected: FAIL because the helper does not exist yet.

- [ ] **Step 3: Add the cycling helper**

```swift
var nextCycleValue: DictationRecognitionLanguage {
    switch self {
    case .mixed: .chinese
    case .chinese: .english
    case .english: .mixed
    }
}
```

- [ ] **Step 4: Run the focused cycling test to verify it passes**

Run: `swift test --filter recognitionLanguageCyclesInApprovedOrder`
Expected: PASS

- [ ] **Step 5: Commit the cycling helper**

```bash
git add Sources/Typeless/Domain/DictationRecognitionLanguage.swift Tests/TypelessTests/ShortcutMenuTests.swift
git commit -m "feat: add recognition mode cycling helper"
```

### Task 4: Replace the static shortcut line with a submenu

**Files:**
- Modify: `Sources/Typeless/App/MenuBar/MenuBarController.swift`
- Create: `Tests/TypelessTests/ShortcutMenuTests.swift`

- [ ] **Step 1: Write the failing test for the dictation shortcut title when enabled**

```swift
@Test
func shortcutMenuShowsDictationShortcutKeyWhenEnabled() {
    let appState = AppState(userDefaults: UserDefaults(suiteName: #function)!)
    let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

    #expect(controller.dictationShortcutMenuTitle == "Dictation Shortcut: Command + Shift + H")
}
```

- [ ] **Step 2: Run the focused title test to verify it fails**

Run: `swift test --filter shortcutMenuShowsDictationShortcutKeyWhenEnabled`
Expected: FAIL because the title helper does not exist yet.

- [ ] **Step 3: Write the failing test for the disabled title**

```swift
@Test
func shortcutMenuShowsDisabledWhenRecognitionModeShortcutIsOff() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.set(false, forKey: "recognitionModeShortcutEnabled")
    let appState = AppState(userDefaults: defaults)
    let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

    #expect(controller.recognitionModeShortcutMenuTitle == "Recognition Mode Shortcut: Disabled")
}
```

- [ ] **Step 4: Run the focused disabled-title test to verify it fails**

Run: `swift test --filter shortcutMenuShowsDisabledWhenRecognitionModeShortcutIsOff`
Expected: FAIL before the submenu helpers exist.

- [ ] **Step 5: Add a `Shortcuts` submenu and remove the static shortcut row**

```swift
let shortcutsMenuItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
shortcutsMenuItem.submenu = shortcutsMenu()
menu.addItem(shortcutsMenuItem)
```

- [ ] **Step 6: Add direct-toggle menu items for both shortcuts**

```swift
private func shortcutsMenu() -> NSMenu {
    let menu = NSMenu()

    let dictationItem = NSMenuItem(
        title: dictationShortcutMenuTitle,
        action: #selector(handleDictationShortcutToggle),
        keyEquivalent: ""
    )
    dictationItem.state = appState.isDictationShortcutEnabled ? .on : .off

    let recognitionModeItem = NSMenuItem(
        title: recognitionModeShortcutMenuTitle,
        action: #selector(handleRecognitionModeShortcutToggle),
        keyEquivalent: ""
    )
    recognitionModeItem.state = appState.isRecognitionModeShortcutEnabled ? .on : .off

    ...
}
```

- [ ] **Step 7: Implement menu-title helpers**

```swift
var dictationShortcutMenuTitle: String {
    appState.isDictationShortcutEnabled
        ? "Dictation Shortcut: Command + Shift + H"
        : "Dictation Shortcut: Disabled"
}

var recognitionModeShortcutMenuTitle: String {
    appState.isRecognitionModeShortcutEnabled
        ? "Recognition Mode Shortcut: Command + Shift + Y"
        : "Recognition Mode Shortcut: Disabled"
}
```

- [ ] **Step 8: Run the shortcut-menu tests**

Run: `swift test --filter ShortcutMenuTests`
Expected: PASS

- [ ] **Step 9: Commit the menu structure**

```bash
git add Sources/Typeless/App/MenuBar/MenuBarController.swift Tests/TypelessTests/ShortcutMenuTests.swift
git commit -m "feat: add shortcut management submenu"
```

### Task 5: Wire toggles to live hotkey registration

**Files:**
- Modify: `Sources/Typeless/App/AppDelegate.swift`
- Modify: `Sources/Typeless/App/MenuBar/MenuBarController.swift`
- Modify: `Tests/TypelessTests/ShortcutMenuTests.swift`

- [ ] **Step 1: Write the failing test for toggling dictation shortcut state**

```swift
@Test
func togglingDictationShortcutUpdatesAppState() {
    let appState = AppState(userDefaults: UserDefaults(suiteName: #function)!)
    let controller = MenuBarController(appState: appState, coordinator: DictationCoordinator(appState: appState))

    controller.performDictationShortcutToggle()

    #expect(appState.isDictationShortcutEnabled == false)
}
```

- [ ] **Step 2: Run the focused toggle test to verify it fails**

Run: `swift test --filter togglingDictationShortcutUpdatesAppState`
Expected: FAIL because the toggle helper does not exist yet.

- [ ] **Step 3: Add independent hotkey managers in `AppDelegate`**

```swift
private var dictationHotkeyManager: GlobalHotkeyManager?
private var recognitionModeHotkeyManager: GlobalHotkeyManager?
```

- [ ] **Step 4: Register or unregister each hotkey based on app state**

```swift
private func refreshHotkeyRegistration() {
    if appState.isDictationShortcutEnabled { ... } else { ... }
    if appState.isRecognitionModeShortcutEnabled { ... } else { ... }
}
```

- [ ] **Step 5: Observe app-state changes and keep hotkeys synchronized**

```swift
appState.onChange = { [weak self] in
    self?.menuBarController?.refreshMenu()
    self?.refreshHotkeyRegistration()
}
```

- [ ] **Step 6: Wire the recognition-mode shortcut action**

```swift
appState.setRecognitionLanguage(appState.selectedRecognitionLanguage.nextCycleValue)
appState.setDebugMessage("Recognition language set to \(appState.selectedRecognitionLanguage.statusDescription)")
```

- [ ] **Step 7: Implement menu toggle handlers**

```swift
@objc
private func handleDictationShortcutToggle() {
    appState.setDictationShortcutEnabled(!appState.isDictationShortcutEnabled)
    appState.setDebugMessage(appState.isDictationShortcutEnabled ? "Dictation shortcut enabled" : "Dictation shortcut disabled")
}
```

```swift
@objc
private func handleRecognitionModeShortcutToggle() {
    appState.setRecognitionModeShortcutEnabled(!appState.isRecognitionModeShortcutEnabled)
    appState.setDebugMessage(appState.isRecognitionModeShortcutEnabled ? "Recognition mode shortcut enabled" : "Recognition mode shortcut disabled")
}
```

- [ ] **Step 8: Run the shortcut and app-state test suites**

Run: `swift test --filter ShortcutMenuTests`
Expected: PASS

Run: `swift test --filter AppStateTests`
Expected: PASS

- [ ] **Step 9: Commit the live toggle behavior**

```bash
git add Sources/Typeless/App/AppDelegate.swift Sources/Typeless/App/MenuBar/MenuBarController.swift Sources/Typeless/Domain/DictationRecognitionLanguage.swift Tests/TypelessTests/ShortcutMenuTests.swift
git commit -m "feat: toggle shortcut registration from menu"
```

### Task 6: Verify the integrated shortcut experience

**Files:**
- Test: `Tests/TypelessTests/AppStateTests.swift`
- Test: `Tests/TypelessTests/GlobalHotkeyManagerTests.swift`
- Test: `Tests/TypelessTests/ShortcutMenuTests.swift`

- [ ] **Step 1: Run the shortcut-focused test suites**

Run: `swift test --filter AppStateTests`
Expected: PASS

Run: `swift test --filter GlobalHotkeyManagerTests`
Expected: PASS

Run: `swift test --filter ShortcutMenuTests`
Expected: PASS

- [ ] **Step 2: Build the app for manual verification**

Run: `./scripts/build_app.sh`
Expected: `App ready: /Users/yichenlin/Desktop/Typeless/dist/noType.app`

- [ ] **Step 3: Launch the app and manually verify**

```text
1. Open `Shortcuts`
2. Disable Dictation Shortcut
3. Confirm the row changes to `Dictation Shortcut: Disabled`
4. Press Command + Shift + H and verify dictation does not start
5. Re-enable it and verify the shortcut works again
6. Disable Recognition Mode Shortcut
7. Confirm the row changes to `Recognition Mode Shortcut: Disabled`
8. Re-enable it and verify Command + Shift + Y cycles A -> 中 -> EN -> A
```

Expected:

- toggles take effect immediately
- only the targeted shortcut changes
- menu labels and checkmarks stay in sync
- no app restart is required

- [ ] **Step 4: Commit any final verification tweaks**

```bash
git add Sources/Typeless/App/AppDelegate.swift Sources/Typeless/App/MenuBar/MenuBarController.swift Sources/Typeless/Hotkey/GlobalHotkeyManager.swift Sources/Typeless/Hotkey/KeyCombination.swift Tests/TypelessTests/AppStateTests.swift Tests/TypelessTests/GlobalHotkeyManagerTests.swift Tests/TypelessTests/ShortcutMenuTests.swift
git commit -m "test: verify shortcut management flow"
```
