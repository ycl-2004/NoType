import AppKit

enum ModifierDoubleTapKey: String, Equatable {
    case command
    case option

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            .command
        case .option:
            .option
        }
    }
}

enum DictationShortcutChoice: String, CaseIterable, Equatable {
    case doubleCommand
    case doubleOption
    case commandShiftH
    case disabled

    var menuTitle: String {
        switch self {
        case .doubleCommand:
            "Double Command"
        case .doubleOption:
            "Double Option"
        case .commandShiftH:
            "Command + Shift + H"
        case .disabled:
            "Disabled"
        }
    }

    var doubleTapKey: ModifierDoubleTapKey? {
        switch self {
        case .doubleCommand:
            .command
        case .doubleOption:
            .option
        case .commandShiftH, .disabled:
            nil
        }
    }

    var keyCombination: KeyCombination? {
        self == .commandShiftH ? .defaultDictationShortcut : nil
    }
}

enum RecognitionModeShortcutChoice: String, CaseIterable, Equatable {
    case commandShiftY
    case commandOptionY
    case controlOptionY
    case disabled

    var menuTitle: String {
        switch self {
        case .commandShiftY:
            "Command + Shift + Y"
        case .commandOptionY:
            "Command + Option + Y"
        case .controlOptionY:
            "Control + Option + Y"
        case .disabled:
            "Disabled"
        }
    }

    var keyCombination: KeyCombination? {
        switch self {
        case .commandShiftY:
            .recognitionModeShortcut
        case .commandOptionY:
            .recognitionModeCommandOptionShortcut
        case .controlOptionY:
            .recognitionModeControlOptionShortcut
        case .disabled:
            nil
        }
    }
}
