import Foundation

enum DictationError: Error, Equatable {
    case microphonePermissionRequired
    case accessibilityPermissionRequired
    case noRecordedAudio
    case invalidAudioInput
    case transcriptionFailed(String)
    case insertionFailed(String)
}

extension DictationError {
    var userMessage: String {
        switch self {
        case .microphonePermissionRequired:
            "Microphone permission required"
        case .accessibilityPermissionRequired:
            "Accessibility permission required"
        case .noRecordedAudio:
            "No audio captured"
        case .invalidAudioInput:
            "Audio input unavailable"
        case let .transcriptionFailed(message):
            "Transcription failed: \(message)"
        case let .insertionFailed(message):
            "Insertion failed: \(message)"
        }
    }
}
