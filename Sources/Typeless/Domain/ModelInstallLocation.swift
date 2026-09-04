import Foundation

/// Where a downloaded Whisper model should live.
///
/// The model is 1.5 GB, so where it lands is the user's call rather than ours: someone who already
/// runs other WhisperKit tools wants the shared folder and no second copy, while someone who wants
/// NoType to own its files — and to take them away when the app is deleted — wants the private one.
enum ModelInstallLocation: String, CaseIterable, Equatable {
    case shared
    case applicationSupport

    /// The directory handed to `WhisperKit.download(downloadBase:)`. The downloader appends
    /// `models/<repo>/<variant>` beneath it, which is why the shared case points at the
    /// `huggingface` root rather than at the model folder itself.
    var downloadBase: URL {
        switch self {
        case .shared:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/huggingface", isDirectory: true)
        case .applicationSupport:
            FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("NoType", isDirectory: true)
        }
    }

    var title: String {
        switch self {
        case .shared:
            "Shared folder"
        case .applicationSupport:
            "NoType's own folder"
        }
    }

    /// Shown on the buttons, so it has to say what the user gets rather than name a path.
    var buttonTitle: String {
        switch self {
        case .shared:
            "Shared Folder"
        case .applicationSupport:
            "NoType Folder"
        }
    }

    var explanation: String {
        switch self {
        case .shared:
            "~/Documents/huggingface — shared with other WhisperKit apps, so they will not download their own copy."
        case .applicationSupport:
            "~/Library/Application Support/NoType — used only by NoType, and removed when you delete the app."
        }
    }

    var displayPath: String {
        downloadBase.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
}
