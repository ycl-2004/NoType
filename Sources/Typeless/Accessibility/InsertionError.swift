import Foundation

enum InsertionError: Error, Equatable {
    case notTrusted
    case unsupportedFocusedElement
    /// The accessibility API accepted a write, but the target did not confirm the new value.
    /// Pasting after this state can duplicate text if the write actually landed.
    case insertionMayHaveSucceeded
    case pasteFailed
    case capturedTargetUnavailable
}
