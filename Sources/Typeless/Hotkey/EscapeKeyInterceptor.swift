import AppKit
import CoreGraphics

/// Turns a plain Escape press into "cancel dictation" while a session is active, and keeps that
/// press away from the focused app.
///
/// The dictation shortcuts use `NSEvent` monitors, which can observe keys but never consume them.
/// Escape must be consumed: it also interrupts an agent running in a terminal, closes dialogs and
/// clears fields, so one press would cancel NoType *and* act on whatever has focus. An active
/// `CGEventTap` can drop the event; it needs the Accessibility permission NoType already uses for
/// insertion. The tap exists only while dictation is recording or transcribing, so ordinary typing
/// never passes through NoType.
/// https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
@MainActor
final class EscapeKeyInterceptor {
    static let escapeKeyCode: Int64 = 53
    /// Escape with Command, Option, Control or Shift is a different gesture and is passed through.
    private static let blockingModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
    /// Bounds how long the tap is kept alive to swallow the release of a consumed press.
    private static let releaseWait: Duration = .seconds(1)

    private let onEscape: @MainActor () -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var awaitingRelease = false
    private var stopRequested = false
    private var releaseWaitTask: Task<Void, Never>?

    init(onEscape: @escaping @MainActor () -> Void) {
        self.onEscape = onEscape
    }

    var isActive: Bool { tap != nil && stopRequested == false }

    /// Returns `false` when macOS refuses the tap, which happens without Accessibility permission.
    @discardableResult
    func start() -> Bool {
        stopRequested = false
        releaseWaitTask?.cancel()
        releaseWaitTask = nil
        if tap != nil { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: escapeTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    /// Removes the tap. If an Escape press was consumed and its release has not arrived yet, the
    /// tap stays briefly so the focused app never receives a release without its press.
    func stop() {
        guard tap != nil else { return }
        stopRequested = true
        guard awaitingRelease else {
            removeTap()
            return
        }
        releaseWaitTask?.cancel()
        releaseWaitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.releaseWait)
            guard Task.isCancelled == false, let self, self.stopRequested else { return }
            self.removeTap()
        }
    }

    /// Returns whether the event is consumed. Internal so the decision can be tested without a tap.
    func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags, isRepeat: Bool) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables a tap whose callback stalls; re-enable rather than silently stop.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown:
            guard stopRequested == false,
                  keyCode == Self.escapeKeyCode,
                  flags.isDisjoint(with: Self.blockingModifiers) else { return false }
            awaitingRelease = true
            if isRepeat == false { onEscape() }
            return true
        case .keyUp:
            guard keyCode == Self.escapeKeyCode, awaitingRelease else { return false }
            awaitingRelease = false
            if stopRequested { removeTap() }
            return true
        default:
            return false
        }
    }

    private func removeTap() {
        releaseWaitTask?.cancel()
        releaseWaitTask = nil
        awaitingRelease = false
        stopRequested = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        runLoopSource = nil
    }
}

/// The tap's run-loop source is on the main run loop, so the callback runs on the main thread.
private func escapeTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let flags = event.flags
    // An address is Sendable; the interceptor it points to is only touched on the main actor.
    let interceptorAddress = UInt(bitPattern: userInfo)
    let consumed = MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: interceptorAddress) else { return false }
        return Unmanaged<EscapeKeyInterceptor>.fromOpaque(pointer).takeUnretainedValue()
            .handle(type: type, keyCode: keyCode, flags: flags, isRepeat: isRepeat)
    }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
