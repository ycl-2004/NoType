import Foundation

enum DownloadedLocalModel: String, CaseIterable, Equatable {
    case r2t2

    var menuTitle: String {
        switch self {
        case .r2t2:
            TranscriptionEngineChoice.r2t2.menuTitle
        }
    }

    var locationDescription: String {
        switch self {
        case .r2t2:
            "The Confucius4-R2T2 GGUF and Q8_0 projector in ~/Documents/huggingface/models/mradermacher"
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
        case .r2t2:
            [R2T2Paths.modelFolder]
        }
    }
}
