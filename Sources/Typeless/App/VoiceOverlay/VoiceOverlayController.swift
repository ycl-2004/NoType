import AppKit
import Combine
import SwiftUI

final class VoiceOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class VoiceOverlayController {
    private let appState: AppState
    let panel: VoiceOverlayPanel
    private var subscriptions = Set<AnyCancellable>()
    private var dismissalTask: Task<Void, Never>?
    private var status: VoiceOverlayStatus = .hidden
    private var enabled: Bool
    private var display: NSScreen?
    private var timing: VoiceOverlayTiming
    private var resultStartedAt: ContinuousClock.Instant?

    init(appState: AppState) {
        self.appState = appState
        enabled = appState.showsVoiceOverlay
        timing = appState.voiceOverlayTiming
        // A nonactivating, click-through panel leaves the captured text field focused.
        // https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
        panel = VoiceOverlayPanel(
            contentRect: NSRect(origin: .zero, size: VoiceOverlayView.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .canJoinAllApplications]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none

        appState.$voiceOverlayStatus.removeDuplicates().sink { [weak self] status in
            self?.statusChanged(status)
        }.store(in: &subscriptions)
        appState.$showsVoiceOverlay.removeDuplicates().sink { [weak self] enabled in
            self?.enabled = enabled
            self?.render()
        }.store(in: &subscriptions)
        appState.$voiceOverlayTiming.removeDuplicates().sink { [weak self] timing in
            self?.timing = timing
            self?.scheduleDismissal()
            self?.render()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.positionPanel() }
            .store(in: &subscriptions)
    }

    private func statusChanged(_ status: VoiceOverlayStatus) {
        dismissalTask?.cancel()
        dismissalTask = nil
        self.status = status
        resultStartedAt = status.isTransient ? .now : nil
        if status == .recording || display == nil {
            display = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        }
        scheduleDismissal()
        render()
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()
        dismissalTask = nil
        guard let duration = timing.duration(for: status), let resultStartedAt else { return }
        // Editing the setting uses the original result time; it never restarts the countdown.
        let remaining = max(Duration.zero, .seconds(duration) - resultStartedAt.duration(to: .now))
        dismissalTask = Task { [weak self] in
            // The fade is included in the selected duration, including the 5-second cap.
            let fade = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Duration.zero : min(.milliseconds(180), remaining)
            try? await Task.sleep(for: remaining - fade)
            guard !Task.isCancelled, let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                let parts = fade.components
                context.duration = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
                self.panel.animator().alphaValue = 0
            }, completionHandler: nil)
            try? await Task.sleep(for: fade)
            guard !Task.isCancelled else { return }
            // Expire the result even while hidden, so toggling the setting cannot revive it.
            self.appState.setVoiceOverlayStatus(.hidden)
        }
    }

    private func render() {
        guard enabled, status != .hidden, timing.duration(for: status) != 0 else {
            panel.orderOut(nil)
            return
        }
        panel.contentView = NSHostingView(rootView: VoiceOverlayView(appState: appState, status: status))
        positionPanel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    static func frame(in visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.midX - VoiceOverlayView.size.width / 2,
            y: visibleFrame.minY + 20,
            width: VoiceOverlayView.size.width,
            height: VoiceOverlayView.size.height
        )
    }

    private func positionPanel() {
        guard let screen = NSScreen.screens.first(where: { $0 == display }) ?? NSScreen.main else { return }
        display = screen
        panel.setFrame(Self.frame(in: screen.visibleFrame), display: true)
    }

    func close() {
        dismissalTask?.cancel()
        dismissalTask = nil
        subscriptions.removeAll()
        panel.orderOut(nil)
    }

    deinit { dismissalTask?.cancel() }
}
