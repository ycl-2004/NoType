import Testing
@testable import Typeless

struct SystemSettingsOpenerTests {
    @Test
    func accessibilitySettingsURLUsesPrivacyAccessibilityPane() throws {
        let url = try #require(SystemSettingsOpener.settingsURL(for: .accessibility))

        #expect(url.absoluteString == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @Test
    func microphoneSettingsURLUsesPrivacyMicrophonePane() throws {
        let url = try #require(SystemSettingsOpener.settingsURL(for: .microphone))

        #expect(url.absoluteString == "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }
}
