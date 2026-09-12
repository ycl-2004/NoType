import AppKit
import Testing
@testable import Typeless

struct ShortcutBindingTests {
    @Test(arguments: [
        (UInt16(14), "e", "E"),
        (UInt16(36), "\r", "Return"),
        (UInt16(127), "", "Key 127"),
        (UInt16(122), "", "F1"), (UInt16(120), "", "F2"),
        (UInt16(99), "", "F3"), (UInt16(118), "", "F4"),
        (UInt16(96), "", "F5"), (UInt16(97), "", "F6"),
        (UInt16(98), "", "F7"), (UInt16(100), "", "F8"),
        (UInt16(101), "", "F9"), (UInt16(109), "", "F10"),
        (UInt16(103), "", "F11"), (UInt16(111), "", "F12"),
        (UInt16(105), "", "F13"), (UInt16(107), "", "F14"),
        (UInt16(113), "", "F15"), (UInt16(106), "", "F16"),
        (UInt16(64), "", "F17"), (UInt16(79), "", "F18"),
        (UInt16(80), "", "F19"), (UInt16(90), "", "F20"),
    ])
    func recordsKeyEventsWithoutCrashing(keyCode: UInt16, characters: String, expectedName: String) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))
        let binding = try #require(ShortcutBinding.fromKeyEvent(event, activeModifiers: [.leftCommand]))

        #expect(binding.keyCode == keyCode)
        #expect(binding.keyName == expectedName)
        #expect(binding.modifiers == [.leftCommand])
        #expect(binding.pressStyle == .single)
    }

    @Test
    func formatsRegularKeyWithSideSpecificModifiers() {
        let binding = ShortcutBinding(
            keyCode: 14,
            keyName: "E",
            modifiers: [.leftCommand, .rightOption],
            pressStyle: .single
        )

        #expect(binding.menuTitle == "Left Command + Right Option + E")
    }

    @Test
    func matchesTheRecordedModifierSidesExactly() {
        let binding = ShortcutBinding(
            keyCode: 14,
            keyName: "E",
            modifiers: [.leftCommand, .rightOption],
            pressStyle: .single
        )

        #expect(binding.matches(
            keyCode: 14,
            activeModifiers: Set([.leftCommand, .rightOption]),
            eventFlags: [.command, .option]
        ))
        #expect(binding.matches(
            keyCode: 14,
            activeModifiers: Set([.rightCommand, .rightOption]),
            eventFlags: [.command, .option]
        ) == false)
    }

    @Test
    func genericModifierMatchesEitherSide() {
        let binding = ShortcutBinding(modifier: .command, pressStyle: .double)

        #expect(binding.matches(releasedModifier: .leftCommand))
        #expect(binding.matches(releasedModifier: .rightCommand))
        #expect(binding.matches(releasedModifier: .leftOption) == false)
    }

    @Test
    func regularKeyCanBeUsedWithoutOrWithModifiers() {
        let plainKey = ShortcutBinding(keyCode: 14, keyName: "E", modifiers: [], pressStyle: .single)
        let modifiedKey = ShortcutBinding(keyCode: 14, keyName: "E", modifiers: [.leftControl], pressStyle: .double)

        #expect(plainKey.menuTitle == "E")
        #expect(modifiedKey.menuTitle == "Double Left Control + E")
        #expect(modifiedKey.pressStyle == .double)
    }

    @Test
    func genericAndSideSpecificBindingsAreRecognizedAsConflicts() {
        let generic = ShortcutBinding(modifier: .command, pressStyle: .single)
        let left = ShortcutBinding(modifier: .leftCommand, pressStyle: .double)

        #expect(generic.conflicts(with: left))
    }

    @Test
    func sameGestureConflictsAcrossPressStyles() {
        let single = ShortcutBinding(keyCode: 14, keyName: "E", modifiers: [.leftCommand], pressStyle: .single)
        let double = single.withPressStyle(.double)

        #expect(single.conflicts(with: double))
    }
}
