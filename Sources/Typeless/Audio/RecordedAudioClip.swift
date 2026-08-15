import Foundation

struct RecordedAudioClip: Equatable {
    let fileURL: URL

    /// How much audio was actually captured. `nil` means the recorder could not report it, which
    /// callers must treat as "long enough" rather than guessing.
    let duration: TimeInterval?

    init(fileURL: URL, duration: TimeInterval? = nil) {
        self.fileURL = fileURL
        self.duration = duration
    }

    /// Recordings are scratch data: once a transcript exists the audio has no further use, and
    /// keeping it would leave every dictation the user has ever spoken on disk.
    func deleteFile() {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            AppLogger.log("RecordedAudioClip: could not delete \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
