import Foundation

struct RecordedAudioClip: Equatable {
    let fileURL: URL

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
