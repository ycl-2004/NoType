import AppKit
import Carbon.HIToolbox
import Testing
@testable import Typeless

@MainActor
struct ShortcutMonitorTests {
    @Test
    func recoversWhenAReleaseWasLostBeforeTheNextSameFamilyTap() throws {
        var pressCount = 0
        let monitor = ShortcutMonitor(bindings: [ShortcutBinding(modifier: .command, pressStyle: .double)]) {
            pressCount += 1
        }

        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_Command), flags: [.command], timestamp: 1.0))
        // The left Command release is intentionally omitted to model a dropped flagsChanged event.
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_RightCommand), flags: [.command], timestamp: 1.1))
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_RightCommand), flags: [], timestamp: 1.2))
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_RightCommand), flags: [.command], timestamp: 1.3))
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_RightCommand), flags: [], timestamp: 1.4))

        #expect(pressCount == 1)
    }

    @Test
    func measuresModifierDoubleTapFromFirstReleaseToSecondPress() throws {
        var pressCount = 0
        let monitor = ShortcutMonitor(bindings: [ShortcutBinding(modifier: .command, pressStyle: .double)]) {
            pressCount += 1
        }

        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_Command), flags: [.command], timestamp: 1.0))
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_Command), flags: [], timestamp: 1.1))
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_Command), flags: [.command], timestamp: 1.3))
        // The second press is held for 0.4s. It should remain valid because the interval
        // is measured from the first release to this press, not from release to release.
        monitor.handle(try modifierEvent(keyCode: UInt16(kVK_Command), flags: [], timestamp: 1.7))

        #expect(pressCount == 1)
    }

    private func modifierEvent(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags,
        timestamp: TimeInterval
    ) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: flags,
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        ))
    }
}
