import Foundation

/// Downloads the official Qwen3-ASR 0.6B INT8 archive into the shared local model directory.
@MainActor
protocol Qwen3ASRModelInstalling {
    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL?
}

@MainActor
final class Qwen3ASRModelInstaller: Qwen3ASRModelInstalling {
    private var installationTask: Task<URL, Error>?

    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL? {
        if Qwen3ASRPaths.modelFolderExists {
            return Qwen3ASRPaths.modelFolder
        }

        if let installationTask {
            return try await installationTask.value
        }

        let task = Task { @MainActor in
            try await Self.downloadAndExtract(progress: progress)
        }
        installationTask = task
        defer { installationTask = nil }

        return try await task.value
    }

    private static func downloadAndExtract(
        progress: @escaping @MainActor (String) -> Void
    ) async throws -> URL {
        let fileManager = FileManager.default
        let baseFolder = Qwen3ASRPaths.sharedModelBaseFolder
        let archiveURL = baseFolder.appendingPathComponent(
            ".\(Qwen3ASRPaths.archiveFileName).download",
            isDirectory: false
        )
        let extractionFolder = baseFolder.appendingPathComponent(
            ".\(Qwen3ASRPaths.modelPackageName).extract",
            isDirectory: true
        )

        try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: archiveURL)
        try? fileManager.removeItem(at: extractionFolder)

        defer {
            try? fileManager.removeItem(at: archiveURL)
            try? fileManager.removeItem(at: extractionFolder)
        }

        progress("Downloading Qwen3-ASR 0.6B INT8 to \(Qwen3ASRPaths.displayPath(baseFolder))…")
        let (downloadedURL, response) = try await URLSession.shared.download(
            from: Qwen3ASRPaths.modelDownloadURL
        )
        if let response = response as? HTTPURLResponse,
           (200..<300).contains(response.statusCode) == false {
            throw TranscriptionError.modelUnavailable(
                "Qwen3-ASR download failed with HTTP status \(response.statusCode)."
            )
        }
        try fileManager.moveItem(at: downloadedURL, to: archiveURL)

        progress("Extracting Qwen3-ASR 0.6B INT8…")
        try fileManager.createDirectory(at: extractionFolder, withIntermediateDirectories: true)
        try extractArchive(archiveURL, to: extractionFolder)

        let extractedModelFolder = extractionFolder
            .appendingPathComponent(Qwen3ASRPaths.modelPackageName, isDirectory: true)
        guard requiredModelFilesExist(in: extractedModelFolder, fileManager: fileManager) else {
            throw TranscriptionError.modelUnavailable(
                "The downloaded Qwen3-ASR archive did not contain the expected INT8 model files."
            )
        }

        // Replace only this exact model directory. A partial install may be left by an interrupted
        // download, while all other files in the shared Hugging Face directory belong elsewhere.
        try? fileManager.removeItem(at: Qwen3ASRPaths.modelFolder)
        try fileManager.moveItem(at: extractedModelFolder, to: Qwen3ASRPaths.modelFolder)
        progress("Qwen3-ASR 0.6B INT8 model downloaded")
        return Qwen3ASRPaths.modelFolder
    }

    private static func requiredModelFilesExist(
        in folder: URL,
        fileManager: FileManager
    ) -> Bool {
        let paths = [
            folder.appendingPathComponent(Qwen3ASRPaths.convFrontendFileName),
            folder.appendingPathComponent(Qwen3ASRPaths.encoderFileName),
            folder.appendingPathComponent(Qwen3ASRPaths.decoderFileName),
            folder.appendingPathComponent(Qwen3ASRPaths.tokenizerDirectoryName, isDirectory: true),
        ]
        return paths.allSatisfy { fileManager.fileExists(atPath: $0.path) }
    }

    private static func extractArchive(_ archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archiveURL.path, "-C", destinationURL.path]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: error, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = message?.isEmpty == false ? ": \(message!)" : "."
            throw TranscriptionError.modelUnavailable(
                "Could not extract the Qwen3-ASR model\(detail)"
            )
        }
    }
}
