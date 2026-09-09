import Foundation

enum DownloadedLocalModel: String, CaseIterable, Equatable {
    case whisper
    case senseVoice

    var menuTitle: String {
        switch self {
        case .whisper:
            "Whisper"
        case .senseVoice:
            "SenseVoice Small"
        }
    }

    var locationDescription: String {
        switch self {
        case .whisper:
            "Downloaded Whisper copies in ~/Documents/huggingface and NoType Application Support"
        case .senseVoice:
            "The SenseVoice copy in ~/Documents/huggingface"
        }
    }
}

@MainActor
protocol LocalModelRemoving {
    func isInstalled(_ model: DownloadedLocalModel) -> Bool
    func remove(_ model: DownloadedLocalModel) throws -> Bool
}

/// Removes only model directories owned by NoType.
///
/// macOS Speech assets are managed by the operating system and are deliberately absent from this
/// service. The app never asks `SpeechTranscriber` or `AssetInventory` to remove anything.
@MainActor
final class LocalModelManager: LocalModelRemoving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isInstalled(_ model: DownloadedLocalModel) -> Bool {
        Self.managedPaths(for: model).contains { fileManager.fileExists(atPath: $0.path) }
    }

    @discardableResult
    func remove(_ model: DownloadedLocalModel) throws -> Bool {
        var removedAny = false
        for path in Self.managedPaths(for: model) where fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
            removedAny = true
        }
        return removedAny
    }

    nonisolated static func managedPaths(for model: DownloadedLocalModel) -> [URL] {
        switch model {
        case .whisper:
            // The app's bundle is intentionally excluded. A release bundle may contain Whisper for
            // offline first use, but a menu action must never mutate the signed app bundle.
            ModelInstallLocation.allCases.map { location in
                LocalWhisperPaths.modelFolder(under: location.downloadBase)
            }
        case .senseVoice:
            [SenseVoicePaths.modelFolder]
        }
    }
}
