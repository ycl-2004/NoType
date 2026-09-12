import Foundation

enum DownloadedLocalModel: String, CaseIterable, Equatable {
    case qwen3ASR
    case senseVoice

    var menuTitle: String {
        switch self {
        case .qwen3ASR:
            "Qwen3-ASR 0.6B INT8"
        case .senseVoice:
            "SenseVoice Small"
        }
    }

    var locationDescription: String {
        switch self {
        case .qwen3ASR:
            "The Qwen3-ASR 0.6B INT8 copy in ~/Documents/huggingface/models/k2-fsa"
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
        case .qwen3ASR:
            [Qwen3ASRPaths.modelFolder]
        case .senseVoice:
            [SenseVoicePaths.modelFolder]
        }
    }
}
