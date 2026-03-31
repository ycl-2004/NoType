import Foundation

enum InsertionError: Error, Equatable {
    case notTrusted
    case unsupportedFocusedElement
    case pasteFailed
    case capturedTargetUnavailable
}
