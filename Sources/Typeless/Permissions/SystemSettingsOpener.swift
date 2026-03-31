import AppKit
import Foundation

enum PermissionSettingsDestination {
    case accessibility
    case microphone
}

@MainActor
protocol PermissionSettingsOpening {
    func openSettings(for destination: PermissionSettingsDestination)
}

@MainActor
struct SystemSettingsOpener: PermissionSettingsOpening {
    func openSettings(for destination: PermissionSettingsDestination) {
        guard let url = Self.settingsURL(for: destination) else { return }
        NSWorkspace.shared.open(url)
    }

    nonisolated static func settingsURL(for destination: PermissionSettingsDestination) -> URL? {
        let rawValue: String = switch destination {
        case .accessibility:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .microphone:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }

        return URL(string: rawValue)
    }
}
