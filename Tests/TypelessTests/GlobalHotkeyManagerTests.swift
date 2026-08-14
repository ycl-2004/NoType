import Carbon.HIToolbox
import Testing
@testable import Typeless

struct GlobalHotkeyManagerTests {
    @Test
    func definesRecognitionModeShortcut() {
        #expect(
            KeyCombination.recognitionModeShortcut == KeyCombination(
                keyCode: UInt32(kVK_ANSI_Y),
                modifiers: UInt32(cmdKey | shiftKey)
            )
        )
    }

    @Test
    func configurableRecognitionShortcutsUseDifferentCombinations() {
        #expect(
            RecognitionModeShortcutChoice.commandShiftY.keyCombination !=
                RecognitionModeShortcutChoice.commandOptionY.keyCombination
        )
        #expect(
            RecognitionModeShortcutChoice.commandOptionY.keyCombination !=
                RecognitionModeShortcutChoice.controlOptionY.keyCombination
        )
        #expect(RecognitionModeShortcutChoice.disabled.keyCombination == nil)
    }

    @Test
    func dictationShortcutSupportsDoubleTapLegacyAndDisabledModes() {
        #expect(DictationShortcutChoice.doubleCommand.doubleTapKey == .command)
        #expect(DictationShortcutChoice.doubleOption.doubleTapKey == .option)
        #expect(DictationShortcutChoice.commandShiftH.keyCombination == .defaultDictationShortcut)
        #expect(DictationShortcutChoice.disabled.keyCombination == nil)
        #expect(DictationShortcutChoice.disabled.doubleTapKey == nil)
    }

    @Test
    func hotkeyManagerUsesDistinctIdentifiersPerShortcut() {
        #expect(GlobalHotkeyManager.HotkeyKind.dictation.id != GlobalHotkeyManager.HotkeyKind.recognitionModeCycle.id)
    }

    @Test
    func hotkeyManagerUsesDistinctRegistryKeysPerShortcut() {
        #expect(
            GlobalHotkeyManager.HotkeyKind.dictation.registryKey !=
                GlobalHotkeyManager.HotkeyKind.recognitionModeCycle.registryKey
        )
    }
}
