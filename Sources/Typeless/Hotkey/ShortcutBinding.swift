import AppKit
import Carbon.HIToolbox

enum ShortcutPressStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case single
    case double

    var menuTitle: String {
        switch self {
        case .single:
            "Single Press"
        case .double:
            "Double Press"
        }
    }
}

/// A modifier key, retaining left/right identity when macOS provides it.
enum ShortcutModifier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case command
    case leftCommand
    case rightCommand
    case option
    case leftOption
    case rightOption
    case control
    case leftControl
    case rightControl
    case shift
    case leftShift
    case rightShift
    case function

    var family: Family {
        switch self {
        case .command, .leftCommand, .rightCommand:
            .command
        case .option, .leftOption, .rightOption:
            .option
        case .control, .leftControl, .rightControl:
            .control
        case .shift, .leftShift, .rightShift:
            .shift
        case .function:
            .function
        }
    }

    var isSideSpecific: Bool {
        switch self {
        case .leftCommand, .rightCommand, .leftOption, .rightOption, .leftControl, .rightControl,
             .leftShift, .rightShift:
            true
        case .command, .option, .control, .shift, .function:
            false
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch family {
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

    var displayName: String {
        switch self {
        case .command:
            "Command"
        case .leftCommand:
            "Left Command"
        case .rightCommand:
            "Right Command"
        case .option:
            "Option"
        case .leftOption:
            "Left Option"
        case .rightOption:
            "Right Option"
        case .control:
            "Control"
        case .leftControl:
            "Left Control"
        case .rightControl:
            "Right Control"
        case .shift:
            "Shift"
        case .leftShift:
            "Left Shift"
        case .rightShift:
            "Right Shift"
        case .function:
            "Fn"
        }
    }

    var keyCode: UInt16? {
        switch self {
        case .command, .option, .control, .shift:
            nil
        case .leftCommand:
            UInt16(kVK_Command)
        case .rightCommand:
            UInt16(kVK_RightCommand)
        case .leftOption:
            UInt16(kVK_Option)
        case .rightOption:
            UInt16(kVK_RightOption)
        case .leftControl:
            UInt16(kVK_Control)
        case .rightControl:
            UInt16(kVK_RightControl)
        case .leftShift:
            UInt16(kVK_Shift)
        case .rightShift:
            UInt16(kVK_RightShift)
        case .function:
            UInt16(kVK_Function)
        }
    }

    static func sideSpecificModifier(for keyCode: UInt16) -> ShortcutModifier? {
        switch keyCode {
        case UInt16(kVK_Command):
            .leftCommand
        case UInt16(kVK_RightCommand):
            .rightCommand
        case UInt16(kVK_Option):
            .leftOption
        case UInt16(kVK_RightOption):
            .rightOption
        case UInt16(kVK_Control):
            .leftControl
        case UInt16(kVK_RightControl):
            .rightControl
        case UInt16(kVK_Shift):
            .leftShift
        case UInt16(kVK_RightShift):
            .rightShift
        case UInt16(kVK_Function):
            .function
        default:
            nil
        }
    }

    enum Family: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
        case command
        case option
        case control
        case shift
        case function
    }
}

/// A user-recorded keyboard shortcut. It can be a regular key with any supported modifier
/// combination, or a modifier key by itself for a single or double press.
struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
    let keyCode: UInt16?
    let keyName: String
    let modifiers: [ShortcutModifier]
    let pressStyle: ShortcutPressStyle

    init(
        keyCode: UInt16,
        keyName: String,
        modifiers: [ShortcutModifier],
        pressStyle: ShortcutPressStyle
    ) {
        self.keyCode = keyCode
        self.keyName = keyName
        self.modifiers = Self.normalized(modifiers)
        self.pressStyle = pressStyle
    }

    init(modifier: ShortcutModifier, pressStyle: ShortcutPressStyle) {
        self.keyCode = nil
        self.keyName = modifier.displayName
        self.modifiers = [modifier]
        self.pressStyle = pressStyle
    }

    var isModifierOnly: Bool {
        keyCode == nil
    }

    var modifierFlags: NSEvent.ModifierFlags {
        modifiers.reduce(into: []) { result, modifier in
            result.formUnion(modifier.modifierFlag)
        }
    }

    var menuTitle: String {
        let baseTitle: String
        if isModifierOnly {
            baseTitle = keyName
        } else {
            let modifierTitle = modifiers.map(\.displayName).joined(separator: " + ")
            baseTitle = modifierTitle.isEmpty ? keyName : "\(modifierTitle) + \(keyName)"
        }

        switch pressStyle {
        case .single:
            return baseTitle
        case .double:
            return "Double \(baseTitle)"
        }
    }

    func withPressStyle(_ pressStyle: ShortcutPressStyle) -> ShortcutBinding {
        if let keyCode {
            return ShortcutBinding(
                keyCode: keyCode,
                keyName: keyName,
                modifiers: modifiers,
                pressStyle: pressStyle
            )
        }

        guard let modifier = modifiers.first else { return self }
        return ShortcutBinding(modifier: modifier, pressStyle: pressStyle)
    }

    func conflicts(with other: ShortcutBinding) -> Bool {
        keyCode == other.keyCode && Self.modifierSetsCanOverlap(Set(modifiers), Set(other.modifiers))
    }

    func matches(
        keyCode: UInt16,
        activeModifiers: Set<ShortcutModifier>,
        eventFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard self.keyCode == keyCode, isModifierOnly == false else { return false }

        let relevantEventFlags = eventFlags.intersection(Self.supportedModifierFlags)
        guard relevantEventFlags == modifierFlags else { return false }
        return Self.modifiersMatch(required: Set(modifiers), active: activeModifiers)
    }

    func matches(releasedModifier: ShortcutModifier) -> Bool {
        guard isModifierOnly, let required = modifiers.first else { return false }
        return Self.modifiersMatch(required: [required], active: [releasedModifier])
    }

    static func fromKeyEvent(
        _ event: NSEvent,
        activeModifiers: Set<ShortcutModifier>,
        pressStyle: ShortcutPressStyle = .single
    ) -> ShortcutBinding? {
        guard event.type == .keyDown, event.isARepeat == false else { return nil }
        let modifiers = activeModifiers.filter { event.modifierFlags.contains($0.modifierFlag) }
        return ShortcutBinding(
            keyCode: event.keyCode,
            keyName: keyName(for: event),
            modifiers: Array(modifiers),
            pressStyle: pressStyle
        )
    }

    static func relevantModifierFlags(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection(supportedModifierFlags)
    }

    private static let supportedModifierFlags: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift,
        .function,
    ]

    private static func normalized(_ modifiers: [ShortcutModifier]) -> [ShortcutModifier] {
        let unique = Set(modifiers)
        return unique.sorted { lhs, rhs in
            modifierSortOrder(lhs) < modifierSortOrder(rhs)
        }
    }

    private static func modifierSortOrder(_ modifier: ShortcutModifier) -> Int {
        switch modifier {
        case .command, .leftCommand, .rightCommand:
            0
        case .option, .leftOption, .rightOption:
            1
        case .control, .leftControl, .rightControl:
            2
        case .shift, .leftShift, .rightShift:
            3
        case .function:
            4
        }
    }

    private static func modifiersMatch(
        required: Set<ShortcutModifier>,
        active: Set<ShortcutModifier>
    ) -> Bool {
        let requiredFamilies = Set(required.map(\.family))
        let activeFamilies = Set(active.map(\.family))
        guard requiredFamilies == activeFamilies else { return false }

        for family in requiredFamilies {
            let requiredForFamily = required.filter { $0.family == family }
            let activeForFamily = active.filter { $0.family == family }
            if requiredForFamily.contains(where: { $0.isSideSpecific }) {
                guard requiredForFamily == activeForFamily else { return false }
            }
        }
        return true
    }

    private static func modifierSetsCanOverlap(
        _ lhs: Set<ShortcutModifier>,
        _ rhs: Set<ShortcutModifier>
    ) -> Bool {
        guard Set(lhs.map(\.family)) == Set(rhs.map(\.family)) else { return false }

        for family in Set(lhs.map(\.family)) {
            let leftFamily = lhs.filter { $0.family == family }
            let rightFamily = rhs.filter { $0.family == family }
            let leftIsGeneric = leftFamily.contains { $0.isSideSpecific == false }
            let rightIsGeneric = rightFamily.contains { $0.isSideSpecific == false }

            if leftIsGeneric || rightIsGeneric {
                continue
            }
            guard leftFamily == rightFamily else { return false }
        }
        return true
    }

    private static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case UInt16(kVK_Return):
            return "Return"
        case UInt16(kVK_Tab):
            return "Tab"
        case UInt16(kVK_Space):
            return "Space"
        case UInt16(kVK_Delete):
            return "Delete"
        case UInt16(kVK_Escape):
            return "Escape"
        case UInt16(kVK_ForwardDelete):
            return "Forward Delete"
        case UInt16(kVK_Home):
            return "Home"
        case UInt16(kVK_End):
            return "End"
        case UInt16(kVK_PageUp):
            return "Page Up"
        case UInt16(kVK_PageDown):
            return "Page Down"
        case UInt16(kVK_LeftArrow):
            return "Left Arrow"
        case UInt16(kVK_RightArrow):
            return "Right Arrow"
        case UInt16(kVK_UpArrow):
            return "Up Arrow"
        case UInt16(kVK_DownArrow):
            return "Down Arrow"
        // Carbon function-key codes are neither contiguous nor ordered by F-number.
        case UInt16(kVK_F1):
            return "F1"
        case UInt16(kVK_F2):
            return "F2"
        case UInt16(kVK_F3):
            return "F3"
        case UInt16(kVK_F4):
            return "F4"
        case UInt16(kVK_F5):
            return "F5"
        case UInt16(kVK_F6):
            return "F6"
        case UInt16(kVK_F7):
            return "F7"
        case UInt16(kVK_F8):
            return "F8"
        case UInt16(kVK_F9):
            return "F9"
        case UInt16(kVK_F10):
            return "F10"
        case UInt16(kVK_F11):
            return "F11"
        case UInt16(kVK_F12):
            return "F12"
        case UInt16(kVK_F13):
            return "F13"
        case UInt16(kVK_F14):
            return "F14"
        case UInt16(kVK_F15):
            return "F15"
        case UInt16(kVK_F16):
            return "F16"
        case UInt16(kVK_F17):
            return "F17"
        case UInt16(kVK_F18):
            return "F18"
        case UInt16(kVK_F19):
            return "F19"
        case UInt16(kVK_F20):
            return "F20"
        default:
            let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let characters, characters.isEmpty == false {
                return characters.uppercased()
            }
            return "Key \(event.keyCode)"
        }
    }
}
