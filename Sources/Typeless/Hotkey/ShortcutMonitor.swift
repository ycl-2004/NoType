import AppKit

/// Observes one or more user-defined keyboard gestures and invokes one action for the first match.
@MainActor
final class ShortcutMonitor {
    private let bindings: [ShortcutBinding]
    private let onShortcutPressed: @MainActor () -> Void
    private let maximumTapDuration: TimeInterval = 0.35
    private let maximumIntervalBetweenTaps: TimeInterval = 0.45
    private var activeModifiers: Set<ShortcutModifier> = []
    private var modifierPressStartedAt: [ShortcutModifier: TimeInterval] = [:]
    private var lastModifierTapAt: [ShortcutBinding: TimeInterval] = [:]
    private var lastKeyTapAt: [ShortcutBinding: TimeInterval] = [:]
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(
        bindings: [ShortcutBinding],
        onShortcutPressed: @escaping @MainActor () -> Void
    ) {
        self.bindings = bindings
        self.onShortcutPressed = onShortcutPressed
    }

    func start() -> Bool {
        guard bindings.isEmpty == false else { return false }
        guard globalMonitor == nil, localMonitor == nil else { return true }

        let mask: NSEvent.EventTypeMask = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
            return event
        }

        guard globalMonitor != nil, localMonitor != nil else {
            stop()
            return false
        }
        return true
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        activeModifiers.removeAll()
        modifierPressStartedAt.removeAll()
        lastModifierTapAt.removeAll()
        lastKeyTapAt.removeAll()
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleModifierChange(event)
        case .keyDown:
            handleKeyDown(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            lastModifierTapAt.removeAll()
            lastKeyTapAt.removeAll()
        default:
            break
        }
    }

    private func handleModifierChange(_ event: NSEvent) {
        guard let modifier = ShortcutModifier.sideSpecificModifier(for: event.keyCode) else { return }
        let isPressed = event.modifierFlags.contains(modifier.modifierFlag)
        let wasPressed = activeModifiers.contains(modifier)

        if isPressed, wasPressed == false {
            activeModifiers.insert(modifier)
            modifierPressStartedAt[modifier] = event.timestamp
            return
        }

        guard isPressed == false, wasPressed else { return }
        activeModifiers.remove(modifier)
        let duration = event.timestamp - (modifierPressStartedAt.removeValue(forKey: modifier) ?? event.timestamp)
        guard duration <= maximumTapDuration, activeModifiers.isEmpty else {
            lastModifierTapAt.removeAll()
            return
        }

        for binding in bindings where binding.isModifierOnly && binding.matches(releasedModifier: modifier) {
            if binding.pressStyle == .single {
                onShortcutPressed()
                return
            }
            if recordTap(for: binding, at: event.timestamp, storage: &lastModifierTapAt) {
                onShortcutPressed()
                return
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard event.isARepeat == false else { return }
        lastModifierTapAt.removeAll()

        for binding in bindings where binding.isModifierOnly == false {
            guard binding.matches(
                keyCode: event.keyCode,
                activeModifiers: activeModifiers,
                eventFlags: event.modifierFlags
            ) else {
                lastKeyTapAt.removeValue(forKey: binding)
                continue
            }

            if binding.pressStyle == .single {
                lastKeyTapAt.removeAll()
                onShortcutPressed()
                return
            }

            let previousTap = lastKeyTapAt[binding]
            lastKeyTapAt.removeAll()
            if let previousTap {
                lastKeyTapAt[binding] = previousTap
            }
            if recordTap(for: binding, at: event.timestamp, storage: &lastKeyTapAt) {
                onShortcutPressed()
            }
            return
        }

        // A double press must be made with the same gesture; another key cancels pending pairs.
        lastKeyTapAt.removeAll()
    }

    private func recordTap(
        for binding: ShortcutBinding,
        at timestamp: TimeInterval,
        storage: inout [ShortcutBinding: TimeInterval]
    ) -> Bool {
        guard let previous = storage[binding], timestamp - previous <= maximumIntervalBetweenTaps else {
            storage[binding] = timestamp
            return false
        }
        storage.removeValue(forKey: binding)
        return true
    }
}
