import Foundation
import Testing
@testable import Typeless

@MainActor
struct ModelInstallTests {
    /// The two locations must be genuinely different, or the choice offered to the user is a lie.
    @Test
    func theTwoLocationsAreDistinctAndUnderTheUsersHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shared = ModelInstallLocation.shared.downloadBase.path
        let priv = ModelInstallLocation.applicationSupport.downloadBase.path

        #expect(shared != priv)
        #expect(shared.hasPrefix(home))
        #expect(priv.hasPrefix(home))
    }

    /// `WhisperKit.download(downloadBase:)` appends `models/<repo>/<variant>`, so the layout the
    /// downloader creates has to be the layout the loader searches — otherwise a model downloads
    /// successfully and is then reported as missing.
    @Test
    func downloadLayoutMatchesTheSearchedLayout() {
        for location in ModelInstallLocation.allCases {
            let resolved = LocalWhisperPaths.modelFolder(under: location.downloadBase)

            #expect(resolved.path.hasPrefix(location.downloadBase.path))
            #expect(resolved.path.contains("models/argmaxinc/whisperkit-coreml"))
            #expect(LocalWhisperPaths.searchedModelFolders.contains { $0.path == resolved.path })
        }
    }

    /// Install locations must be searched before the app bundle, so a downloaded model keeps one
    /// stable Core ML cache no matter which build is installed over the top.
    @Test
    func installLocationsAreSearchedBeforeTheAppBundle() {
        let folders = LocalWhisperPaths.searchedModelFolders.map(\.path)
        guard let bundleIndex = folders.firstIndex(where: { $0.contains(".app/Contents/Resources") }) else { return }

        for location in ModelInstallLocation.allCases {
            let installPath = LocalWhisperPaths.modelFolder(under: location.downloadBase).path
            if let index = folders.firstIndex(of: installPath) {
                #expect(index < bundleIndex)
            }
        }
    }

    @Test
    func declinedDownloadReturnsNothingRatherThanInstallingSomewhereUnasked() async throws {
        let installer = WhisperModelInstaller(chooseLocation: { nil })

        // Only meaningful when no model is present; otherwise the installer short-circuits.
        guard LocalWhisperPaths.modelFolderExists == false else { return }

        let result = try await installer.installIfNeeded(progress: { _ in })
        #expect(result == nil)
    }

    /// An install that already exists must not re-download 1.5 GB, and must not even ask.
    @Test
    func existingModelSkipsBothThePromptAndTheDownload() async throws {
        guard LocalWhisperPaths.modelFolderExists else { return }

        var promptShown = false
        let installer = WhisperModelInstaller(chooseLocation: {
            promptShown = true
            return .shared
        })

        let result = try await installer.installIfNeeded(progress: { _ in })

        #expect(promptShown == false)
        #expect(result?.path == LocalWhisperPaths.modelFolder)
    }
}
