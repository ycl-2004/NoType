import Foundation

enum TranscriptionError: Error, Equatable {
    case engineUnavailable
    case failed(String)
}
