enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case error(DictationError)
}
