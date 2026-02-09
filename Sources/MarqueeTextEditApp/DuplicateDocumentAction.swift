import AppKit

enum DuplicateDocumentAction {
    static func duplicate(text: String, fileURL: URL?) async {
        let targetURL: URL

        if let fileURL = fileURL {
            targetURL = nextAvailableDuplicateURL(for: fileURL)
        } else {
            let tempDir = FileManager.default.temporaryDirectory
            targetURL = nextAvailableTemporaryURL(in: tempDir, baseName: "Untitled", ext: "txt")
        }

        do {
            try text.write(to: targetURL, atomically: true, encoding: .utf8)
            _ = try await NSDocumentController.shared.openDocument(withContentsOf: targetURL, display: true)
        } catch {
            NSSound.beep()
        }
    }

    private static func nextAvailableDuplicateURL(for originalURL: URL) -> URL {
        let dir = originalURL.deletingLastPathComponent()
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let ext = originalURL.pathExtension

        var candidate = dir.appendingPathComponent("\(baseName) copy").appendingPathExtension(ext)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(baseName) copy \(index)").appendingPathExtension(ext)
            index += 1
        }

        return candidate
    }

    private static func nextAvailableTemporaryURL(in directory: URL, baseName: String, ext: String) -> URL {
        var candidate = directory.appendingPathComponent("\(baseName) copy").appendingPathExtension(ext)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) copy \(index)").appendingPathExtension(ext)
            index += 1
        }

        return candidate
    }
}
