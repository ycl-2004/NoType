import Foundation
import Testing
@testable import Typeless

@Suite
struct HuggingFaceModelStoreTests {
    @Test
    func everyDownloadRootIsInsideTheSharedHuggingFaceFolder() {
        #expect(R2T2Paths.locationValidationError() == nil)
        #expect(R2T2Paths.sharedModelBaseFolder.path.hasPrefix(HuggingFaceModelStore.root.path + "/"))
    }

    @Test
    func rejectsAPathOutsideTheSharedHuggingFaceFolder() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoType-HuggingFaceRoot-\(UUID().uuidString)", isDirectory: true)
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(
            HuggingFaceModelStore.locationValidationError(
                for: outside.appendingPathComponent("model", isDirectory: true),
                within: root
            ) != nil
        )
    }

    @Test
    func rejectsASymlinkThatResolvesOutsideTheSharedHuggingFaceFolder() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("NoType-HuggingFaceRoot-\(UUID().uuidString)", isDirectory: true)
        let modelFolder = root.appendingPathComponent("models/model", isDirectory: true)
        let outside = fileManager.temporaryDirectory
            .appendingPathComponent("NoType-HuggingFaceOutside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: outside)
        }

        try fileManager.createDirectory(at: root.appendingPathComponent("models"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: modelFolder, withDestinationURL: outside)

        #expect(HuggingFaceModelStore.locationValidationError(for: modelFolder, within: root) != nil)
    }

    @Test
    func r2t2UsesTheRequestedQuantizationsAndStreamingCadence() {
        #expect(R2T2Paths.modelQuantization == "Q4_K_M")
        #expect(R2T2Paths.projectorQuantization == "Q8_0")
        #expect(R2T2Paths.chunkDurationMilliseconds == 320)
        #expect(R2T2Paths.modelURL.pathExtension == "gguf")
        #expect(R2T2Paths.projectorURL.pathExtension == "gguf")
    }
}
