import Foundation

struct VoiceOverlayTiming: Equatable {
    static let defaultDuration = 1.5
    static let maximumDuration = 5.0
    let successDuration: Double
    let failureDuration: Double

    init(successDuration: Double = defaultDuration, failureDuration: Double = defaultDuration) {
        self.successDuration = Self.clamp(successDuration)
        self.failureDuration = Self.clamp(failureDuration)
    }

    func duration(for status: VoiceOverlayStatus) -> Double? {
        guard status.isTransient else { return nil }
        return status.isFailure ? failureDuration : successDuration
    }

    static func label(for seconds: Double) -> String {
        let formatted = inputText(for: seconds)
        return seconds == 0 ? "Hidden (0 seconds)" : "\(formatted) seconds"
    }

    static func inputText(for seconds: Double) -> String {
        String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }

    static func parse(_ input: String) -> Double? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard normalized.isEmpty == false,
              let value = Double(normalized),
              value.isFinite,
              (0...maximumDuration).contains(value) else {
            return nil
        }
        return value
    }

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(maximumDuration, max(0, value)) : defaultDuration
    }
}
