import Foundation

/// Downloads the experimental R2T2 GGUF model and Q8 projector on first use.
@MainActor
protocol R2T2ModelInstalling {
    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL?
}

@MainActor
final class R2T2ModelInstaller: R2T2ModelInstalling {
    private var installationTask: Task<URL, Error>?

    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL? {
        if let locationError = R2T2Paths.locationValidationError() {
            throw TranscriptionError.modelUnavailable(locationError)
        }

        if R2T2Paths.modelFolderExists {
            return R2T2Paths.modelFolder
        }
        if let installationTask {
            return try await installationTask.value
        }

        let task = Task { @MainActor in
            try await Self.downloadFiles(progress: progress)
        }
        installationTask = task
        defer { installationTask = nil }
        return try await task.value
    }

    private static func downloadFiles(
        progress: @escaping @MainActor (String) -> Void
    ) async throws -> URL {
        let fileManager = FileManager.default
        let baseFolder = R2T2Paths.sharedModelBaseFolder
        let stagingFolder = baseFolder
            .appendingPathComponent(".\(R2T2Paths.modelPackageName).download", isDirectory: true)

        guard stagingFolder.path.hasPrefix(R2T2Paths.huggingFaceFolder.path + "/") else {
            throw TranscriptionError.modelUnavailable(
                "R2T2 download staging path must be under \(R2T2Paths.displayPath(R2T2Paths.huggingFaceFolder))."
            )
        }

        try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: stagingFolder)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingFolder) }

        let modelStagingURL = stagingFolder.appendingPathComponent(R2T2Paths.modelFileName)
        let projectorStagingURL = stagingFolder.appendingPathComponent(R2T2Paths.projectorFileName)

        progress("Downloading R2T2 Q4_K_M and Q8_0 projector…")
        try await download(
            R2T2Paths.modelDownloadURL,
            to: modelStagingURL,
            label: "R2T2 Q4_K_M model"
        )
        try await download(
            R2T2Paths.projectorDownloadURL,
            to: projectorStagingURL,
            label: "R2T2 Q8_0 audio projector"
        )

        guard R2T2Paths.locationValidationError() == nil else {
            throw TranscriptionError.modelUnavailable("R2T2 model path validation failed before installation.")
        }

        try? fileManager.removeItem(at: R2T2Paths.modelFolder)
        try fileManager.moveItem(at: stagingFolder, to: R2T2Paths.modelFolder)
        progress("R2T2 model downloaded")
        return R2T2Paths.modelFolder
    }

    private static func download(_ url: URL, to destination: URL, label: String) async throws {
        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        if let response = response as? HTTPURLResponse,
           (200..<300).contains(response.statusCode) == false {
            throw TranscriptionError.modelUnavailable(
                "\(label) download failed with HTTP status \(response.statusCode)."
            )
        }

        do {
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
        } catch {
            throw TranscriptionError.modelUnavailable(
                "Could not store the downloaded \(label): \(error.localizedDescription)"
            )
        }
    }
}
