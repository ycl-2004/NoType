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

        if let installationTask {
            return try await installationTask.value
        }

        let task = Task { @MainActor in
            if R2T2Paths.modelFolderExists {
                progress("Verifying R2T2 model integrity…")
                try await Self.verifyInstalledFiles()
                return R2T2Paths.modelFolder
            }
            if FileManager.default.fileExists(atPath: R2T2Paths.modelFolder.path) {
                throw TranscriptionError.modelUnavailable("R2T2 files are incomplete. Remove R2T2 in Manage Downloaded Models, then retry preparation.")
            }
            return try await Self.downloadFiles(progress: progress)
        }
        installationTask = task
        defer { installationTask = nil }
        return try await task.value
    }

    private nonisolated static let verifiedFiles = UserDefaultsVerifiedModelFileStore()

    private static func verifyInstalledFiles() async throws {
        try await Task.detached(priority: .utility) {
            try R2T2Paths.modelIntegrity.verify(at: R2T2Paths.modelURL, rememberingIn: verifiedFiles)
            try R2T2Paths.projectorIntegrity.verify(at: R2T2Paths.projectorURL, rememberingIn: verifiedFiles)
        }.value
    }

    private static func downloadFiles(
        progress: @escaping @MainActor (String) -> Void
    ) async throws -> URL {
        let fileManager = FileManager.default
        let baseFolder = R2T2Paths.sharedModelBaseFolder
        let stagingFolder = baseFolder
            .appendingPathComponent(".\(R2T2Paths.modelPackageName).\(UUID().uuidString).download", isDirectory: true)

        guard HuggingFaceModelStore.locationValidationError(for: stagingFolder) == nil else {
            throw TranscriptionError.modelUnavailable(
                "R2T2 download staging path must be under \(R2T2Paths.displayPath(R2T2Paths.huggingFaceFolder))."
            )
        }

        try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingFolder) }

        let modelStagingURL = stagingFolder.appendingPathComponent(R2T2Paths.modelFileName)
        let projectorStagingURL = stagingFolder.appendingPathComponent(R2T2Paths.projectorFileName)

        progress("Downloading R2T2 Q4_K_M and Q8_0 projector…")
        try await download(
            R2T2Paths.modelDownloadURL,
            to: modelStagingURL,
            integrity: R2T2Paths.modelIntegrity
        )
        try await download(
            R2T2Paths.projectorDownloadURL,
            to: projectorStagingURL,
            integrity: R2T2Paths.projectorIntegrity
        )

        guard R2T2Paths.locationValidationError() == nil else {
            throw TranscriptionError.modelUnavailable("R2T2 model path validation failed before installation.")
        }

        // Another process may have finished first. Never replace its model directory blindly.
        if fileManager.fileExists(atPath: R2T2Paths.modelFolder.path) {
            try await verifyInstalledFiles()
            return R2T2Paths.modelFolder
        }
        try fileManager.moveItem(at: stagingFolder, to: R2T2Paths.modelFolder)
        progress("R2T2 model downloaded")
        return R2T2Paths.modelFolder
    }

    private static func download(_ url: URL, to destination: URL, integrity: ModelFileIntegrity) async throws {
        let label = integrity.name
        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: downloadedURL) }
        if let response = response as? HTTPURLResponse,
           (200..<300).contains(response.statusCode) == false {
            throw TranscriptionError.modelUnavailable(
                "\(label) download failed with HTTP status \(response.statusCode)."
            )
        }

        // A fresh download has no remembered identity, so this always hashes. Remembering the
        // result lets the first launch after installation skip a second full hash.
        try await Task.detached(priority: .utility) {
            try integrity.verify(at: downloadedURL, rememberingIn: verifiedFiles)
        }.value
        do {
            try FileManager.default.moveItem(at: downloadedURL, to: destination)
        } catch {
            throw TranscriptionError.modelUnavailable(
                "Could not store the downloaded \(label): \(error.localizedDescription)"
            )
        }
    }
}
