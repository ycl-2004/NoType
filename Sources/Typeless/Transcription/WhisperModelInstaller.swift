import AppKit
import Foundation
@preconcurrency import WhisperKit

/// Asks where the Whisper model should go, then downloads it there.
///
/// A release that bundles the model never reaches this code. It exists for the lightweight build —
/// a 10 MB download instead of 1.5 GB — where the model arrives on first use instead, and for any
/// install whose model was moved or deleted.
@MainActor
protocol WhisperModelInstalling {
    /// Returns the folder the model was installed into, or `nil` if the user declined.
    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL?
}

@MainActor
final class WhisperModelInstaller: WhisperModelInstalling {
    /// The variant name `WhisperKit.download` matches against the repository listing.
    private static let variant = "large-v3-v20240930_turbo"

    private let chooseLocation: () async -> ModelInstallLocation?

    init(chooseLocation: (() async -> ModelInstallLocation?)? = nil) {
        self.chooseLocation = chooseLocation ?? { await Self.askUserForLocation() }
    }

    func installIfNeeded(progress: @escaping @MainActor (String) -> Void) async throws -> URL? {
        if LocalWhisperPaths.modelFolderExists {
            return URL(fileURLWithPath: LocalWhisperPaths.modelFolder)
        }

        guard let location = await chooseLocation() else {
            AppLogger.log("ModelInstaller: user declined to download the model")
            return nil
        }

        AppLogger.log("ModelInstaller: downloading \(Self.variant) into \(location.displayPath)")
        progress("Downloading the speech model to \(location.displayPath)…")

        try FileManager.default.createDirectory(
            at: location.downloadBase,
            withIntermediateDirectories: true
        )

        // WhisperKit reports progress from its own download queue, far more often than a menu
        // title should change, so the throttle both crosses actors safely and thins the updates.
        let throttle = ProgressThrottle { percent in
            Task { @MainActor in
                progress("Downloading the speech model… \(percent)%")
            }
        }
        let downloaded = try await Self.performDownload(
            downloadBase: location.downloadBase,
            throttle: throttle
        )

        AppLogger.log("ModelInstaller: downloaded model to \(downloaded.path)")
        progress("Speech model downloaded")
        return downloaded
    }

    /// `nonisolated` so the progress closure is created outside the main actor. WhisperKit's
    /// callback parameter is not `Sendable`, and a closure that inherited this class's `@MainActor`
    /// isolation would be rejected as a data race when handed to the downloader.
    private nonisolated static func performDownload(
        downloadBase: URL,
        throttle: ProgressThrottle
    ) async throws -> URL {
        try await WhisperKit.download(
            variant: variant,
            downloadBase: downloadBase,
            progressCallback: { throttle.report($0.fractionCompleted) }
        )
    }

    /// A menu-bar-only app has no window to attach a sheet to, so this is a standalone alert and
    /// the app is activated first — otherwise it opens behind whatever the user is working in.
    private static func askUserForLocation() async -> ModelInstallLocation? {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Download the speech model?"
        alert.informativeText = """
        NoType needs the Whisper speech model (about 1.5 GB) for Auto (中英混说) recognition. \
        Choose where to keep it.

        \(ModelInstallLocation.shared.title): \(ModelInstallLocation.shared.explanation)

        \(ModelInstallLocation.applicationSupport.title): \(ModelInstallLocation.applicationSupport.explanation)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: ModelInstallLocation.shared.buttonTitle)
        alert.addButton(withTitle: ModelInstallLocation.applicationSupport.buttonTitle)
        alert.addButton(withTitle: "Not Now")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .shared
        case .alertSecondButtonReturn:
            return .applicationSupport
        default:
            return nil
        }
    }
}

/// Crosses from WhisperKit's download queue to the main actor, reporting only every fifth percent.
private final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastReportedPercent = -1
    private let onUpdate: @Sendable (Int) -> Void

    init(onUpdate: @escaping @Sendable (Int) -> Void) {
        self.onUpdate = onUpdate
    }

    func report(_ fraction: Double) {
        let percent = min(100, max(0, Int(fraction * 100)))

        lock.lock()
        let isNewMilestone = percent != lastReportedPercent && percent.isMultiple(of: 5)
        if isNewMilestone {
            lastReportedPercent = percent
        }
        lock.unlock()

        guard isNewMilestone else { return }
        onUpdate(percent)
    }
}
