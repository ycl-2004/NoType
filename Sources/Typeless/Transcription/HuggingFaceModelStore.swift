import Foundation

/// The one filesystem boundary shared by every downloadable NoType model.
enum HuggingFaceModelStore {
    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface", isDirectory: true)
    }

    static func locationValidationError(
        for modelFolder: URL,
        requiredPaths: [URL] = [],
        within root: URL = HuggingFaceModelStore.root
    ) -> String? {
        let rootURL = root.standardizedFileURL
        let folderURL = modelFolder.standardizedFileURL
        guard isWithin(folderURL, root: rootURL) else {
            return "Model path must be under \(displayPath(rootURL))."
        }

        let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedFolder = folderURL.resolvingSymlinksInPath().standardizedFileURL
        guard isWithin(resolvedFolder, root: resolvedRoot) else {
            return "Model path resolves outside \(displayPath(rootURL))."
        }

        for requiredPath in requiredPaths where FileManager.default.fileExists(atPath: requiredPath.path) {
            let resolvedPath = requiredPath.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
            guard isWithin(resolvedPath, root: resolvedRoot) else {
                return "Model file resolves outside \(displayPath(rootURL))."
            }
        }
        return nil
    }

    static func displayPath(_ url: URL) -> String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    private static func isWithin(_ url: URL, root: URL) -> Bool {
        url.path == root.path || url.path.hasPrefix(root.path + "/")
    }
}
