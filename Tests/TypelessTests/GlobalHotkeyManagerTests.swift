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
    func hotkeyManagerUsesDistinctIdentifiersPerShortcut() {
        #expect(GlobalHotkeyManager.HotkeyKind.dictation.id != GlobalHotkeyManager.HotkeyKind.recognitionModeCycle.id)
    }
}
