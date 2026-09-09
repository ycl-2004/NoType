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
            "It will prepare automatically when needed."
        case .preparing:
            "Preparing for dictation. The first setup may take a few minutes."
        case .ready:
            "Ready for dictation."
        case .failed:
            "Couldn’t prepare the speech model. Try again or view the debug log."
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
