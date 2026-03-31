import Foundation

enum TranscriptionError: Error, Equatable {
    case engineUnavailable
    case modelUnavailable(String)
    case failed(String)
}
