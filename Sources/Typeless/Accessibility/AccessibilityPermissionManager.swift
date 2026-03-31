@preconcurrency import ApplicationServices

@MainActor
protocol AccessibilityPermissionManaging {
    func isTrusted() -> Bool
    func promptIfNeeded()
}

@MainActor
struct AccessibilityPermissionManager: AccessibilityPermissionManaging {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
