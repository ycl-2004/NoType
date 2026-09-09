import AppKit
import Testing
@testable import Typeless

struct ShortcutBindingTests {
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
