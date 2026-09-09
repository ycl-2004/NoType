import Foundation

/// Downloads SenseVoice into the one shared Hugging Face model directory.
@MainActor
protocol SenseVoiceModelInstalling {
    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL?
}

@MainActor
final class SenseVoiceModelInstaller: SenseVoiceModelInstalling {
    private var installationTask: Task<URL, Error>?

    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL? {
        if SenseVoicePaths.modelFolderExists {
            return SenseVoicePaths.modelFolder
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
        let baseFolder = SenseVoicePaths.sharedModelBaseFolder
        let archiveURL = baseFolder.appendingPathComponent(
            ".\(SenseVoicePaths.archiveFileName).download",
            isDirectory: false
        )
        let extractionFolder = baseFolder.appendingPathComponent(
            ".\(SenseVoicePaths.modelPackageName).extract",
            isDirectory: true
        )

        try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: archiveURL)
        try? fileManager.removeItem(at: extractionFolder)

        defer {
            try? fileManager.removeItem(at: archiveURL)
            try? fileManager.removeItem(at: extractionFolder)
        }

        progress("Downloading SenseVoice to \(SenseVoicePaths.displayPath(baseFolder))…")
        let (downloadedURL, response) = try await URLSession.shared.download(
            from: SenseVoicePaths.modelDownloadURL
        )
        if let response = response as? HTTPURLResponse,
           (200..<300).contains(response.statusCode) == false {
            throw TranscriptionError.modelUnavailable(
                "SenseVoice download failed with HTTP status \(response.statusCode)."
            )
        }
        try fileManager.moveItem(at: downloadedURL, to: archiveURL)

        progress("Extracting SenseVoice…")
        try fileManager.createDirectory(at: extractionFolder, withIntermediateDirectories: true)
        try extractArchive(archiveURL, to: extractionFolder)

        let extractedModelFolder = extractionFolder
            .appendingPathComponent(SenseVoicePaths.modelPackageName, isDirectory: true)
        let extractedModelURL = extractedModelFolder.appendingPathComponent(SenseVoicePaths.modelFileName)
        let extractedTokensURL = extractedModelFolder.appendingPathComponent(SenseVoicePaths.tokensFileName)
        guard fileManager.fileExists(atPath: extractedModelURL.path),
              fileManager.fileExists(atPath: extractedTokensURL.path) else {
            throw TranscriptionError.modelUnavailable(
                "The downloaded SenseVoice archive did not contain the expected model files."
            )
        }

        // Replace only this exact model directory. It can be a partial folder left by an
        // interrupted installation, while all other files in the shared Hugging Face directory
        // belong to other models and must remain untouched.
        try? fileManager.removeItem(at: SenseVoicePaths.modelFolder)
        try fileManager.moveItem(at: extractedModelFolder, to: SenseVoicePaths.modelFolder)
        progress("SenseVoice model downloaded")
        return SenseVoicePaths.modelFolder
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
                "Could not extract the SenseVoice model\(detail)"
            )
        }
    }
}
