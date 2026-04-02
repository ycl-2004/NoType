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

        var registryKey: UInt64 {
            (UInt64(signature) << 32) | UInt64(id)
        }
    }

    private static var registeredManagers: [UInt64: GlobalHotkeyManager] = [:]
    private static var sharedEventHandlerRef: EventHandlerRef?

    private var hotKeyRef: EventHotKeyRef?
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

    func register() -> Bool {
        guard hotKeyRef == nil else { return true }
        guard Self.installSharedEventHandlerIfNeeded() else {
            AppLogger.log("Failed to install shared hotkey event handler for \(hotkeyKind)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: hotkeyKind.signature, id: hotkeyKind.id)
        let status = RegisterEventHotKey(
            keyCombination.keyCode,
            keyCombination.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, hotKeyRef != nil else {
            AppLogger.log(
                "Failed to register hotkey \(hotkeyKind) " +
                    "(keyCode: \(keyCombination.keyCode), modifiers: \(keyCombination.modifiers), status: \(status))"
            )
            hotKeyRef = nil
            return false
        }

        Self.registeredManagers[hotkeyKind.registryKey] = self
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        Self.registeredManagers.removeValue(forKey: hotkeyKind.registryKey)
        if Self.registeredManagers.isEmpty, let handlerRef = Self.sharedEventHandlerRef {
            RemoveEventHandler(handlerRef)
            Self.sharedEventHandlerRef = nil
        }
    }

    private func manager(for registryKey: UInt64) -> GlobalHotkeyManager? {
        Self.registeredManagers[registryKey]
    }

    private static func installSharedEventHandlerIfNeeded() -> Bool {
        guard sharedEventHandlerRef == nil else { return true }

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

            let managerType = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let registryKey = HotkeyKind.registryKey(signature: hotKeyID.signature, id: hotKeyID.id)
            guard let manager = managerType.manager(for: registryKey) else {
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

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(GlobalHotkeyManager.placeholderManager).toOpaque(),
            &sharedEventHandlerRef
        )
        return status == noErr && sharedEventHandlerRef != nil
    }

    private static let placeholderManager = GlobalHotkeyManager(
        hotkeyKind: .dictation,
        keyCombination: .defaultDictationShortcut
    ) {}
}

private func fourCharCode(from string: String) -> FourCharCode {
    string.utf16.reduce(0) { partialResult, scalar in
        (partialResult << 8) + FourCharCode(scalar)
    }
}

private extension GlobalHotkeyManager.HotkeyKind {
    static func registryKey(signature: FourCharCode, id: UInt32) -> UInt64 {
        (UInt64(signature) << 32) | UInt64(id)
    }
}
