import Foundation

enum AudioSessionError: Error, Equatable {
    case recorderUnavailable
    case missingOutputFile
    case alreadyRecording
    case failedToPrepareRecorder
    case captureFailed(String)
    case invalidInputFormat
}
