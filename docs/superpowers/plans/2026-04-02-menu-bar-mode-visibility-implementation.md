# Menu Bar Mode Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the menu bar icon show the current recognition mode at a glance and, when relevant, show whether Chinese output is set to simplified or traditional.

**Architecture:** Keep `MenuBarController` responsible for menu construction, but move icon composition into a dedicated renderer that generates an `NSImage` from app state, recognition mode, and Chinese script preference. Implement the feature incrementally with renderer-focused tests first, then wire the renderer into the status item update path while preserving the existing recording/transcribing/error state behavior.

**Tech Stack:** Swift, AppKit, NSImage drawing, Swift Testing

---

## File Map

- Create: `Sources/Typeless/App/MenuBar/MenuBarIconRenderer.swift`
  Responsibility: compose the base symbol and lightweight top-right / bottom-right markers into a final status item image.
- Modify: `Sources/Typeless/App/MenuBar/MenuBarController.swift`
  Responsibility: delegate status item image creation to the new renderer and keep menu construction unchanged.
- Modify: `Sources/Typeless/Domain/DictationRecognitionLanguage.swift`
  Responsibility: provide compact mode marker text for the top-right overlay.
- Modify: `Sources/Typeless/Domain/ChineseScriptPreference.swift`
  Responsibility: provide compact script marker text and visibility rules for the bottom-right overlay.
- Modify: `Tests/TypelessTests/AppStateTests.swift`
  Responsibility: add or adjust state expectations only if renderer wiring requires new observable behavior.
- Create: `Tests/TypelessTests/MenuBarIconRendererTests.swift`
  Responsibility: cover marker mapping and visibility decisions without depending on manual UI inspection.

### Task 1: Define compact marker semantics

**Files:**
- Modify: `Sources/Typeless/Domain/DictationRecognitionLanguage.swift`
- Modify: `Sources/Typeless/Domain/ChineseScriptPreference.swift`
- Create: `Tests/TypelessTests/MenuBarIconRendererTests.swift`

- [ ] **Step 1: Write the failing test for recognition mode marker text**

```swift
@Test
func recognitionLanguageProvidesCompactMenuBarMarker() {
    #expect(DictationRecognitionLanguage.mixed.menuBarMarker == "A")
    #expect(DictationRecognitionLanguage.chinese.menuBarMarker == "中")
    #expect(DictationRecognitionLanguage.english.menuBarMarker == "EN")
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter recognitionLanguageProvidesCompactMenuBarMarker`
Expected: FAIL because `menuBarMarker` does not exist yet.

- [ ] **Step 3: Write the failing test for Chinese script marker visibility**

```swift
@Test
func chineseScriptMarkerVisibilityMatchesRecognitionMode() {
    #expect(ChineseScriptPreference.simplified.shouldShowMenuBarMarker(for: .mixed) == true)
    #expect(ChineseScriptPreference.traditional.shouldShowMenuBarMarker(for: .chinese) == true)
    #expect(ChineseScriptPreference.traditional.shouldShowMenuBarMarker(for: .english) == false)
}
```

- [ ] **Step 4: Run the focused visibility test to verify it fails**

Run: `swift test --filter chineseScriptMarkerVisibilityMatchesRecognitionMode`
Expected: FAIL because visibility helpers do not exist yet.

- [ ] **Step 5: Add compact marker helpers**

```swift
var menuBarMarker: String {
    switch self {
    case .mixed: "A"
    case .chinese: "中"
    case .english: "EN"
    }
}
```

```swift
var menuBarMarker: String {
    switch self {
    case .followModel: ""
    case .simplified: "简"
    case .traditional: "繁"
    }
}

func shouldShowMenuBarMarker(for language: DictationRecognitionLanguage) -> Bool {
    guard self != .followModel else { return false }

    switch language {
    case .mixed, .chinese:
        return true
    case .english:
        return false
    }
}
```

- [ ] **Step 6: Run the focused tests to verify they pass**

Run: `swift test --filter MenuBarIconRendererTests`
Expected: PASS for the new marker-mapping cases.

- [ ] **Step 7: Commit the marker semantics**

```bash
git add Sources/Typeless/Domain/DictationRecognitionLanguage.swift Sources/Typeless/Domain/ChineseScriptPreference.swift Tests/TypelessTests/MenuBarIconRendererTests.swift
git commit -m "feat: add menu bar mode marker mappings"
```

### Task 2: Add a dedicated menu bar icon renderer

**Files:**
- Create: `Sources/Typeless/App/MenuBar/MenuBarIconRenderer.swift`
- Create: `Tests/TypelessTests/MenuBarIconRendererTests.swift`

- [ ] **Step 1: Write the failing test for hiding the script marker in English mode**

```swift
@Test
func rendererDoesNotShowScriptMarkerForEnglishMode() {
    let configuration = MenuBarIconRenderer.Configuration(
        state: .idle,
        recognitionLanguage: .english,
        chineseScriptPreference: .traditional
    )

    #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == nil)
}
```

- [ ] **Step 2: Run the focused renderer test to verify it fails**

Run: `swift test --filter rendererDoesNotShowScriptMarkerForEnglishMode`
Expected: FAIL because the renderer type does not exist yet.

- [ ] **Step 3: Write the failing test for using the right top-right marker**

```swift
@Test
func rendererUsesRecognitionMarkerFromLanguage() {
    let configuration = MenuBarIconRenderer.Configuration(
        state: .recording,
        recognitionLanguage: .mixed,
        chineseScriptPreference: .traditional
    )

    #expect(MenuBarIconRenderer.modeMarker(for: configuration) == "A")
}
```

- [ ] **Step 4: Run the focused marker test to verify it fails**

Run: `swift test --filter rendererUsesRecognitionMarkerFromLanguage`
Expected: FAIL before renderer helpers are implemented.

- [ ] **Step 5: Implement the renderer skeleton**

```swift
import AppKit

enum MenuBarIconRenderer {
    struct Configuration: Equatable {
        let state: DictationState
        let recognitionLanguage: DictationRecognitionLanguage
        let chineseScriptPreference: ChineseScriptPreference
    }

    static func makeImage(for configuration: Configuration) -> NSImage? {
        // compose base symbol image and optional corner markers
    }

    static func modeMarker(for configuration: Configuration) -> String {
        configuration.recognitionLanguage.menuBarMarker
    }

    static func scriptMarker(for configuration: Configuration) -> String? {
        configuration.chineseScriptPreference.shouldShowMenuBarMarker(for: configuration.recognitionLanguage)
            ? configuration.chineseScriptPreference.menuBarMarker
            : nil
    }
}
```

- [ ] **Step 6: Add the first-pass drawing implementation**

```swift
let baseImage = NSImage(systemSymbolName: symbolName(for: configuration.state), accessibilityDescription: "noType")
// draw base image into a small canvas
// draw top-right marker with small semibold font
// draw bottom-right marker when non-nil
// keep everything monochrome / template-friendly outside the existing active state behavior
```

- [ ] **Step 7: Run the renderer tests to verify they pass**

Run: `swift test --filter MenuBarIconRendererTests`
Expected: PASS for marker mapping and visibility behavior.

- [ ] **Step 8: Commit the renderer**

```bash
git add Sources/Typeless/App/MenuBar/MenuBarIconRenderer.swift Tests/TypelessTests/MenuBarIconRendererTests.swift
git commit -m "feat: add menu bar icon renderer"
```

### Task 3: Wire the renderer into the menu bar controller

**Files:**
- Modify: `Sources/Typeless/App/MenuBar/MenuBarController.swift`
- Test: `Tests/TypelessTests/MenuBarIconRendererTests.swift`

- [ ] **Step 1: Write the failing test for preserving the current state symbol mapping**

```swift
@Test
func rendererUsesWaveformSymbolWhileTranscribing() {
    let configuration = MenuBarIconRenderer.Configuration(
        state: .transcribing,
        recognitionLanguage: .mixed,
        chineseScriptPreference: .simplified
    )

    #expect(MenuBarIconRenderer.symbolName(for: configuration.state) == "waveform")
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter rendererUsesWaveformSymbolWhileTranscribing`
Expected: FAIL because the symbol helper is not exposed yet.

- [ ] **Step 3: Refactor `MenuBarController` to build a renderer configuration**

```swift
let configuration = MenuBarIconRenderer.Configuration(
    state: appState.dictationState,
    recognitionLanguage: appState.selectedRecognitionLanguage,
    chineseScriptPreference: appState.selectedChineseScriptPreference
)
```

- [ ] **Step 4: Replace direct SF Symbol creation with renderer output**

```swift
button.image = MenuBarIconRenderer.makeImage(for: configuration)
button.imagePosition = .imageOnly
button.title = ""
```

- [ ] **Step 5: Add a fallback path to the base symbol if rendering fails**

```swift
if let image = MenuBarIconRenderer.makeImage(for: configuration) {
    button.image = image
} else {
    button.image = fallbackSymbolImage(for: configuration.state)
}
```

- [ ] **Step 6: Run focused tests to verify symbol selection behavior still passes**

Run: `swift test --filter MenuBarIconRendererTests`
Expected: PASS with the renderer wired in.

- [ ] **Step 7: Commit the controller integration**

```bash
git add Sources/Typeless/App/MenuBar/MenuBarController.swift Sources/Typeless/App/MenuBar/MenuBarIconRenderer.swift Tests/TypelessTests/MenuBarIconRendererTests.swift
git commit -m "feat: show mode markers in menu bar icon"
```

### Task 4: Verify the full user-facing behavior

**Files:**
- Test: `Tests/TypelessTests/MenuBarIconRendererTests.swift`
- Test: `Tests/TypelessTests/AppStateTests.swift`

- [ ] **Step 1: Add a regression test for hiding the script marker when preference is `followModel`**

```swift
@Test
func rendererHidesScriptMarkerWhenChineseScriptFollowsModel() {
    let configuration = MenuBarIconRenderer.Configuration(
        state: .idle,
        recognitionLanguage: .mixed,
        chineseScriptPreference: .followModel
    )

    #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == nil)
}
```

- [ ] **Step 2: Add a regression test for showing `繁` in `Auto` mode**

```swift
@Test
func rendererShowsTraditionalMarkerForAutoMode() {
    let configuration = MenuBarIconRenderer.Configuration(
        state: .idle,
        recognitionLanguage: .mixed,
        chineseScriptPreference: .traditional
    )

    #expect(MenuBarIconRenderer.scriptMarker(for: configuration) == "繁")
}
```

- [ ] **Step 3: Run the renderer test suite**

Run: `swift test --filter MenuBarIconRendererTests`
Expected: PASS

- [ ] **Step 4: Run the adjacent state tests to catch regressions**

Run: `swift test --filter AppStateTests`
Expected: PASS

- [ ] **Step 5: Build the app for a manual menu bar sanity check**

Run: `./scripts/build_app.sh`
Expected: `App ready: /Users/yichenlin/Desktop/Typeless/dist/noType.app`

- [ ] **Step 6: Launch the app and visually check these states**

```text
Idle + Auto + 繁
Idle + 中文优先 + 简
Idle + 英文优先
Recording + Auto + 繁
Transcribing + 中文优先 + 简
```

Expected:

- top-right marker is always visible and readable
- bottom-right marker only appears for `Auto` and `中文优先`
- recording highlight remains the dominant state signal
- icon does not expand into a wide text item

- [ ] **Step 7: Commit the verification pass if any final tweaks were needed**

```bash
git add Sources/Typeless/App/MenuBar/MenuBarController.swift Sources/Typeless/App/MenuBar/MenuBarIconRenderer.swift Tests/TypelessTests/MenuBarIconRendererTests.swift
git commit -m "test: verify menu bar mode visibility behavior"
```
