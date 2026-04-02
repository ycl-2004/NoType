import Carbon.HIToolbox

struct KeyCombination: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultDictationShortcut = KeyCombination(
        keyCode: UInt32(kVK_ANSI_H),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let recognitionModeShortcut = KeyCombination(
        keyCode: UInt32(kVK_ANSI_Y),
        modifiers: UInt32(cmdKey | shiftKey)
    )
}
