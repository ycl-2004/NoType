import AppKit
import Testing
@testable import Typeless

@MainActor
struct VoiceOverlayTests {
    @Test
    func allOverlayMessagesStayUnderFiveCharacters() {
        for status in VoiceOverlayStatus.allCases where status != .hidden {
            #expect((1..<5).contains(status.text.count))
        }
    }

    @Test
    func preferencesPersistAndZeroIsNotMistakenForMissing() {
        let name = "VoiceOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let state = AppState(userDefaults: defaults)
        #expect(state.showsVoiceOverlay)
        #expect(state.voiceOverlayTiming == VoiceOverlayTiming(successDuration: 1.5, failureDuration: 1.5))
        state.showsVoiceOverlay = false
        state.setVoiceOverlayDuration(0, forFailure: false)
        state.setVoiceOverlayDuration(5, forFailure: true)
        let restored = AppState(userDefaults: defaults)
        #expect(!restored.showsVoiceOverlay)
        #expect(restored.voiceOverlayTiming.successDuration == 0)
        #expect(restored.voiceOverlayTiming.failureDuration == 5)
    }

    @Test
    func invalidDurationsAreBoundedAndContinuousStatesHaveNoTimeout() {
        let timing = VoiceOverlayTiming(successDuration: -1, failureDuration: 200)
        #expect(timing.duration(for: .copied) == 0)
        #expect(timing.duration(for: .insertionFailed) == 5)
        #expect(timing.duration(for: .recording) == nil)
        #expect(timing.duration(for: .transcribing) == nil)
        #expect(VoiceOverlayTiming(successDuration: .nan).successDuration == 1.5)
    }

    @Test
    func levelsDoNotRefreshMenusAndLateSamplesCannotReviveWaveform() {
        let state = makeOverlayState()
        state.update(for: .recording)
        var menuRefreshes = 0
        state.onChange = { menuRefreshes += 1 }
        state.appendVoiceAudioLevel(0.6)
        #expect(state.voiceAudioLevels.last == 0.6)
        #expect(menuRefreshes == 0)
        state.update(for: .transcribing)
        state.appendVoiceAudioLevel(1)
        #expect(state.voiceAudioLevels.allSatisfy { $0 == 0 })
        #expect(state.voiceOverlayStatus == .transcribing)
    }

    @Test
    func meterMappingRespondsToSpeechAndRejectsInvalidReadings() {
        #expect(AudioRecorder.normalizedLevel(decibels: -160) == 0)
        #expect(AudioRecorder.normalizedLevel(decibels: -55) == 0)
        #expect(AudioRecorder.normalizedLevel(decibels: -30) > 0)
        #expect(AudioRecorder.normalizedLevel(decibels: -10) > AudioRecorder.normalizedLevel(decibels: -30))
        #expect(AudioRecorder.normalizedLevel(decibels: 10) == 1)
        #expect(AudioRecorder.normalizedLevel(decibels: .nan) == 0)
    }

    @Test
    func bottomCenterPlacementRespectsDockAndSecondaryScreenCoordinates() {
        let screen = NSRect(x: -1920, y: 90, width: 1920, height: 990)
        let frame = VoiceOverlayController.frame(in: screen)
        #expect(frame.midX == screen.midX)
        #expect(frame.minY == screen.minY + 20)
        #expect(screen.contains(frame))
    }

    @Test
    func menuUsesEnglishOverlayLabelsAndParsesCustomDurations() throws {
        let state = makeOverlayState()
        let controller = MenuBarController(appState: state, coordinator: DictationCoordinator(appState: state))
        let menu = controller.voiceOverlayTimingMenu()
        #expect(menu.items.map(\.title) == ["Completion: 1.5 seconds…", "Failure: 1.5 seconds…"])
        #expect(VoiceOverlayTiming.inputText(for: 0) == "0")
        #expect(VoiceOverlayTiming.inputText(for: 1.5) == "1.5")
        #expect(VoiceOverlayTiming.parse("2.75") == 2.75)
        #expect(VoiceOverlayTiming.parse("2,75") == 2.75)
        #expect(VoiceOverlayTiming.parse("5.1") == nil)
        #expect(VoiceOverlayTiming.parse("not a number") == nil)
        #expect(DictationRecognitionLanguage.english.menuTitle == "English")
        #expect(DictationRecognitionLanguage.chinese.menuTitle == "中文优先")
        let toggle = try #require(controller.makeMenu().items.first { $0.title == "Show Voice Overlay" })
        #expect(NSApplication.shared.sendAction(try #require(toggle.action), to: toggle.target, from: toggle))
        #expect(!state.showsVoiceOverlay)
    }
}

@Suite(.serialized)
@MainActor
struct VoiceOverlayWindowTests {
    @Test
    func recordingShowsImmediatelyWithoutTakingFocusAndCanBeHidden() {
        let state = makeOverlayState()
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        state.update(for: .recording)
        #expect(controller.panel.isVisible)
        #expect(!controller.panel.canBecomeKey && !controller.panel.canBecomeMain)
        #expect(!controller.panel.isKeyWindow)
        #expect(controller.panel.ignoresMouseEvents)
        #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost)
        state.showsVoiceOverlay = false
        #expect(!controller.panel.isVisible)
        state.showsVoiceOverlay = true
        #expect(controller.panel.isVisible)
    }

    @Test
    func zeroHidesSuccessButStillShowsRecordingAndFailure() {
        let state = makeOverlayState()
        state.setVoiceOverlayDuration(0, forFailure: false)
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        state.update(for: .recording)
        #expect(controller.panel.isVisible)
        state.setVoiceOverlayStatus(.inserted)
        #expect(!controller.panel.isVisible)
        state.setError(.insertionFailed("test"))
        #expect(controller.panel.isVisible)
    }

    @Test
    func editingDurationExpiresExistingResultAndDoesNotReviveIt() async throws {
        let state = makeOverlayState()
        state.setVoiceOverlayDuration(5, forFailure: false)
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        state.setVoiceOverlayStatus(.copied)
        #expect(controller.panel.isVisible)
        state.setVoiceOverlayDuration(0, forFailure: false)
        #expect(!controller.panel.isVisible)
        try await Task.sleep(for: .milliseconds(100))
        #expect(state.voiceOverlayStatus == .hidden)
        state.setVoiceOverlayDuration(5, forFailure: false)
        state.showsVoiceOverlay = false
        state.showsVoiceOverlay = true
        #expect(!controller.panel.isVisible)
    }

    @Test(arguments: [100, 380])
    func previousCountdownCannotDismissNextRecording(startDelay: Int) async throws {
        let state = makeOverlayState()
        state.setVoiceOverlayDuration(0.5, forFailure: false)
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        state.setVoiceOverlayStatus(.copied)
        // Cover both the hold and the active fade: cancelling a Task alone must not
        // leave an AppKit alpha animation fading out the next session.
        try await Task.sleep(for: .milliseconds(startDelay))
        state.update(for: .recording)
        try await Task.sleep(for: .milliseconds(600))
        #expect(state.voiceOverlayStatus == .recording)
        #expect(controller.panel.isVisible)
        #expect(controller.panel.alphaValue == 1)
    }

    @Test
    func resultsExpireEvenWhenOverlayIsDisabled() async throws {
        let state = makeOverlayState()
        state.showsVoiceOverlay = false
        state.setVoiceOverlayDuration(0.5, forFailure: true)
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        state.setError(.transcriptionFailed("test detail"))
        try await Task.sleep(for: .milliseconds(700))
        state.showsVoiceOverlay = true
        #expect(!controller.panel.isVisible)
        #expect(state.lastError == .transcriptionFailed("test detail"))
    }

    // Optional native rendering evidence. Uses the actual NSHostingView and window, not HTML.
    @Test
    func captureNativeStatesWhenRequested() async throws {
        guard let path = ProcessInfo.processInfo.environment["NOTYPE_OVERLAY_QA_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let state = makeOverlayState()
        let controller = VoiceOverlayController(appState: state)
        defer { controller.close() }
        state.update(for: .recording)
        for level in [0.25, 0.6, 0.95, 0.65, 0.35] { state.appendVoiceAudioLevel(level) }
        for status in [VoiceOverlayStatus.recording, .transcribing, .inserted, .copied, .insertionFailed] {
            state.setVoiceOverlayStatus(status)
            try await Task.sleep(for: .milliseconds(250))
            let view = try #require(controller.panel.contentView)
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("\(status).png"))
        }
    }
}

@MainActor
private func makeOverlayState() -> AppState {
    AppState(userDefaults: UserDefaults(suiteName: "VoiceOverlayTests.\(UUID().uuidString)")!)
}
