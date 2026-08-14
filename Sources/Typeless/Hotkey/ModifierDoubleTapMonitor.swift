import AppKit

struct ModifierDoubleTapDetector {
    private(set) var isPressed = false
    private var pressStartedAt: TimeInterval?
    private var lastCompletedTapAt: TimeInterval?
    let maximumTapDuration: TimeInterval
    let maximumIntervalBetweenTaps: TimeInterval

    init(
        maximumTapDuration: TimeInterval = 0.35,
        maximumIntervalBetweenTaps: TimeInterval = 0.45
    ) {
        self.maximumTapDuration = maximumTapDuration
        self.maximumIntervalBetweenTaps = maximumIntervalBetweenTaps
    }

    mutating func modifierChanged(isPressed: Bool, timestamp: TimeInterval) -> Bool {
        if isPressed {
            guard !self.isPressed else { return false }
            self.isPressed = true
            pressStartedAt = timestamp
            return false
        }

        guard self.isPressed, let pressStartedAt else { return false }
        self.isPressed = false
        self.pressStartedAt = nil

        guard timestamp - pressStartedAt <= maximumTapDuration else {
            lastCompletedTapAt = nil
            return false
        }

        if let lastCompletedTapAt,
           timestamp - lastCompletedTapAt <= maximumIntervalBetweenTaps {
            self.lastCompletedTapAt = nil
            return true
        }

        lastCompletedTapAt = timestamp
        return false
    }

    mutating func cancelSequence() {
        isPressed = false
        pressStartedAt = nil
        lastCompletedTapAt = nil
    }
}

@MainActor
final class ModifierDoubleTapMonitor {
    private let modifierKey: ModifierDoubleTapKey
    private let onDoubleTap: @MainActor () -> Void
    private var detector = ModifierDoubleTapDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(
        modifierKey: ModifierDoubleTapKey,
        onDoubleTap: @escaping @MainActor () -> Void
    ) {
        self.modifierKey = modifierKey
        self.onDoubleTap = onDoubleTap
    }

    func start() -> Bool {
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
        detector.cancelSequence()
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            detector.cancelSequence()
            return
        }

        let activeFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let targetFlag = modifierKey.modifierFlag
        let unrelatedFlags = activeFlags.subtracting(targetFlag)
        guard unrelatedFlags.isEmpty else {
            detector.cancelSequence()
            return
        }

        if detector.modifierChanged(
            isPressed: activeFlags.contains(targetFlag),
            timestamp: event.timestamp
        ) {
            onDoubleTap()
        }
    }
}
