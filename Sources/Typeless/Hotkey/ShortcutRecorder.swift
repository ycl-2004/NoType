import AppKit

/// Captures one key or key combination from a modal menu-bar alert.
@MainActor
enum ShortcutRecorder {
    static func record() -> ShortcutBinding? {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Set a Shortcut"
        alert.informativeText = "Press a key or key combination now.\n\nUse Command, Option, Control, Shift, or Fn with a regular key. To use a modifier by itself, press and release it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cancel")

        let captureSession = ShortcutCaptureSession(alert: alert)
        guard let binding = captureSession.capture() else { return nil }

        let styleAlert = NSAlert()
        styleAlert.messageText = "Choose Activation"
        styleAlert.informativeText = "\(binding.menuTitle)\n\nChoose whether NoType should respond to one press or two quick presses."
        styleAlert.alertStyle = .informational
        styleAlert.addButton(withTitle: ShortcutPressStyle.single.menuTitle)
        styleAlert.addButton(withTitle: ShortcutPressStyle.double.menuTitle)
        styleAlert.addButton(withTitle: "Cancel")

        let style: ShortcutPressStyle?
        switch styleAlert.runModal() {
        case .alertFirstButtonReturn:
            style = .single
        case .alertSecondButtonReturn:
            style = .double
        default:
            style = nil
        }

        return style.map(binding.withPressStyle)
    }
}

@MainActor
private final class ShortcutCaptureSession {
    private let alert: NSAlert
    private var monitor: Any?
    private var activeModifiers: Set<ShortcutModifier> = []
    private var pendingModifier: ShortcutModifier?
    private(set) var binding: ShortcutBinding?

    init(alert: NSAlert) {
        self.alert = alert
    }

    func capture() -> ShortcutBinding? {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
            return self?.binding == nil ? event : nil
        }

        guard monitor != nil else { return nil }
        defer {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        _ = alert.runModal()
        return binding
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            guard let captured = ShortcutBinding.fromKeyEvent(event, activeModifiers: activeModifiers) else { return }
            pendingModifier = nil
            binding = captured
            NSApp.stopModal(withCode: .alertFirstButtonReturn)

        case .flagsChanged:
            guard let modifier = ShortcutModifier.sideSpecificModifier(for: event.keyCode) else { return }
            let isPressed = event.modifierFlags.contains(modifier.modifierFlag)

            if isPressed {
                activeModifiers.insert(modifier)
                pendingModifier = activeModifiers.count == 1 ? modifier : nil
            } else {
                activeModifiers.remove(modifier)
                if activeModifiers.isEmpty, let pendingModifier {
                    binding = ShortcutBinding(modifier: pendingModifier, pressStyle: .single)
                    self.pendingModifier = nil
                    NSApp.stopModal(withCode: .alertFirstButtonReturn)
                } else {
                    pendingModifier = nil
                }
            }

        default:
            break
        }
    }
}
