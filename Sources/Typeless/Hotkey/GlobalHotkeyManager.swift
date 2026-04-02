import Carbon
import Foundation

@MainActor
final class GlobalHotkeyManager {
    enum HotkeyKind {
        case dictation
        case recognitionModeCycle

        var id: UInt32 {
            switch self {
            case .dictation:
                1
            case .recognitionModeCycle:
                2
            }
        }

        var signature: FourCharCode {
            fourCharCode(from: "TYPL")
        }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotkeyKind: HotkeyKind
    private let keyCombination: KeyCombination
    private let onHotkeyPressed: @MainActor () -> Void
    private var lastTriggerTime: CFAbsoluteTime = 0
    private let minimumTriggerInterval: CFAbsoluteTime = 0.35

    init(
        hotkeyKind: HotkeyKind = .dictation,
        keyCombination: KeyCombination = .defaultDictationShortcut,
        onHotkeyPressed: @escaping @MainActor () -> Void
    ) {
        self.hotkeyKind = hotkeyKind
        self.keyCombination = keyCombination
        self.onHotkeyPressed = onHotkeyPressed
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            guard hotKeyID.signature == manager.hotkeyKind.signature,
                  hotKeyID.id == manager.hotkeyKind.id else {
                return noErr
            }
            Task { @MainActor in
                let now = CFAbsoluteTimeGetCurrent()
                guard now - manager.lastTriggerTime > manager.minimumTriggerInterval else {
                    return
                }
                manager.lastTriggerTime = now
                manager.onHotkeyPressed()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: hotkeyKind.signature, id: hotkeyKind.id)
        RegisterEventHotKey(
            keyCombination.keyCode,
            keyCombination.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

private func fourCharCode(from string: String) -> FourCharCode {
    string.utf16.reduce(0) { partialResult, scalar in
        (partialResult << 8) + FourCharCode(scalar)
    }
}
