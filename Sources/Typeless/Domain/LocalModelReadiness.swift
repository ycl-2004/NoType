enum LocalModelReadiness: Equatable {
    case waiting
    case preparing
    case ready
    case failed(String)

    var menuTitle: String {
        switch self {
        case .waiting:
            "Waiting"
        case .preparing:
            "Preparing…"
        case .ready:
            "Ready"
        case .failed:
            "Failed"
        }
    }

    var detailText: String {
        switch self {
        case .waiting:
            "Preparation starts automatically after launch."
        case .preparing:
            "First preparation can take 1–2 minutes. Keep NoType open."
        case .ready:
            "Turbo is loaded. Cached launches should be much faster."
        case .failed:
            "Preparation did not complete. Retry or inspect the debug log."
        }
    }

    var symbolName: String {
        switch self {
        case .waiting:
            "circle.dotted"
        case .preparing:
            "hourglass"
        case .ready:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var failureReason: String? {
        guard case let .failed(reason) = self else { return nil }
        return reason
    }
}
