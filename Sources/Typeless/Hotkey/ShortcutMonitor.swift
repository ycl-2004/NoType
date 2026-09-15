import AppKit

/// Observes one or more user-defined keyboard gestures and invokes one action for the first match.
@MainActor
final class ShortcutMonitor {
    private let bindings: [ShortcutBinding]
    private let onShortcutPressed: @MainActor () -> Void
    private let maximumTapDuration: TimeInterval = 0.45
    private let maximumIntervalBetweenTaps: TimeInterval = 0.5
    private static let modifierStateWatchdogInterval: Duration = .milliseconds(250)
    private var activeModifiers: Set<ShortcutModifier> = []
    private var modifierPressStartedAt: [ShortcutModifier: TimeInterval] = [:]
    private var lastModifierTapAt: [ShortcutBinding: TimeInterval] = [:]
    private var pendingModifierDoubleTaps: Set<ShortcutBinding> = []
    private var lastKeyTapAt: [ShortcutBinding: TimeInterval] = [:]
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var modifierStateWatchdog: Task<Void, Never>?

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

        modifierStateWatchdog = Task { @MainActor [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: Self.modifierStateWatchdogInterval)
                guard Task.isCancelled == false, let self else { return }
                self.reconcileModifierState(with: NSEvent.modifierFlags)
            }
        }
        return true
    }

    func stop() {
        modifierStateWatchdog?.cancel()
        modifierStateWatchdog = nil
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
        pendingModifierDoubleTaps.removeAll()
        lastKeyTapAt.removeAll()
    }

    // Internal so the event state machine can be exercised without installing global monitors.
    func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleModifierChange(event)
        case .keyDown:
            reconcileModifierState(with: event.modifierFlags)
            handleKeyDown(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            reconcileModifierState(with: event.modifierFlags)
            lastModifierTapAt.removeAll()
            pendingModifierDoubleTaps.removeAll()
            lastKeyTapAt.removeAll()
        default:
            break
        }
    }

    private func handleModifierChange(_ event: NSEvent) {
        guard let modifier = ShortcutModifier.sideSpecificModifier(for: event.keyCode) else { return }
        let isPressed = event.modifierFlags.contains(modifier.modifierFlag)
        // Reconcile unrelated families on every flagsChanged event. Preserve the current
        // family until its side-specific press/release transition is interpreted below.
        reconcileModifierState(with: event.modifierFlags, preserving: modifier.family)
        let wasPressed = activeModifiers.contains(modifier)

        if isPressed, wasPressed == false {
            activeModifiers.insert(modifier)
            modifierPressStartedAt[modifier] = event.timestamp
            prepareModifierDoubleTap(for: modifier, at: event.timestamp)
            return
        }

        guard isPressed == false, wasPressed else { return }
        activeModifiers.remove(modifier)
        let duration = event.timestamp - (modifierPressStartedAt.removeValue(forKey: modifier) ?? event.timestamp)

        // The current family flag is now off. Clear every side-specific entry in that
        // family, including one whose release event was lost earlier.
        reconcileModifierFamily(modifier.family)
        guard duration <= maximumTapDuration, activeModifiers.isEmpty else {
            lastModifierTapAt.removeAll()
            pendingModifierDoubleTaps.removeAll()
            return
        }

        for binding in bindings where binding.isModifierOnly && binding.matches(releasedModifier: modifier) {
            if binding.pressStyle == .single {
                onShortcutPressed()
                return
            }

            if pendingModifierDoubleTaps.remove(binding) != nil {
                lastModifierTapAt.removeValue(forKey: binding)
                onShortcutPressed()
                return
            }

            lastModifierTapAt[binding] = event.timestamp
        }
    }

    private func prepareModifierDoubleTap(for modifier: ShortcutModifier, at timestamp: TimeInterval) {
        let matchingBindings = bindings.filter {
            $0.isModifierOnly && $0.pressStyle == .double && $0.matches(releasedModifier: modifier)
        }
        guard matchingBindings.isEmpty == false else {
            lastModifierTapAt.removeAll()
            pendingModifierDoubleTaps.removeAll()
            return
        }

        for binding in matchingBindings {
            guard let previousTap = lastModifierTapAt[binding] else {
                pendingModifierDoubleTaps.remove(binding)
                continue
            }

            if timestamp - previousTap <= maximumIntervalBetweenTaps {
                pendingModifierDoubleTaps.insert(binding)
            } else {
                lastModifierTapAt.removeValue(forKey: binding)
                pendingModifierDoubleTaps.remove(binding)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard event.isARepeat == false else { return }
        lastModifierTapAt.removeAll()
        pendingModifierDoubleTaps.removeAll()

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

    /// Reconciles the event-derived side-specific state with AppKit's current family flags.
    /// `NSEvent.modifierFlags` is independent of which events were delivered, so it can
    /// recover from a dropped `flagsChanged` release without restarting the monitor.
    private func reconcileModifierState(
        with flags: NSEvent.ModifierFlags,
        preserving familyToPreserve: ShortcutModifier.Family? = nil
    ) {
        for family in ShortcutModifier.Family.allCases where family != familyToPreserve {
            guard flags.contains(family.modifierFlag) == false else { continue }
            reconcileModifierFamily(family)
        }
    }

    private func reconcileModifierFamily(_ family: ShortcutModifier.Family) {
        let hadTrackedState = activeModifiers.contains { $0.family == family }
            || modifierPressStartedAt.keys.contains { $0.family == family }
        activeModifiers = activeModifiers.filter { $0.family != family }
        modifierPressStartedAt = modifierPressStartedAt.filter { $0.key.family != family }

        guard hadTrackedState else { return }
        lastModifierTapAt = lastModifierTapAt.filter { $0.key.modifiers.contains { $0.family != family } }
        pendingModifierDoubleTaps = pendingModifierDoubleTaps.filter {
            $0.modifiers.contains { $0.family != family }
        }
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

private extension ShortcutModifier.Family {
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            .command
        case .option:
            .option
        case .control:
            .control
        case .shift:
            .shift
        case .function:
            .function
        }
    }
}
