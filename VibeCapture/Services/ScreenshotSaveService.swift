import AppKit

enum SaveError: LocalizedError {
    case noFolderSelected
    case bookmarkResolveFailed
    case imageEncodingFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noFolderSelected:
            return "No save folder selected."
        case .bookmarkResolveFailed:
            return "Unable to access the save folder."
        case .imageEncodingFailed:
            return "Failed to encode image."
        case .writeFailed(let err):
            return "Failed to save screenshot: \(err.localizedDescription)"
        }
    }
}

final class ScreenshotSaveService {
    static let shared = ScreenshotSaveService()
    private init() {}

    /// Saves a PNG file to the user-chosen folder (security-scoped).
    /// Returns true if saved, false if saving is disabled or user cancelled folder selection.
    func saveIfEnabled(image: NSImage) throws -> Bool {
        guard SettingsStore.shared.saveEnabled else { return false }
        return try saveToFolderAndReturnURL(image: image) != nil
    }

    /// Save screenshot to configured path, or prompt user to choose if not configured.
    /// Uses the same folder as auto-save. If no folder is set, prompts user to choose one.
    func saveScreenshot(image: NSImage) throws -> Bool {
        return try saveToFolderAndReturnURL(image: image) != nil
    }

    /// Save screenshot and return the file URL if successful.
    /// Returns nil if the user cancels folder selection.
    func saveScreenshotAndReturnURL(image: NSImage) throws -> URL? {
        return try saveToFolderAndReturnURL(image: image)
    }

    /// Core save logic: save to configured folder, or prompt user to choose
    private func saveToFolderAndReturnURL(image: NSImage) throws -> URL? {
        guard let data = image.pngData() else { throw SaveError.imageEncodingFailed }

        let folderURL: URL
        if let existing = try resolveFolderURLFromBookmark() {
            folderURL = existing
        } else {
            guard let chosen = chooseFolder() else { return nil }
            folderURL = chosen
            try storeBookmark(for: folderURL)
        }

        var didStart = false
        didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { folderURL.stopAccessingSecurityScopedResource() }
        }

        let filename = Self.defaultFilename()
        let url = uniqueURL(in: folderURL, filename: filename)

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw SaveError.writeFailed(error)
        }
    }

    func chooseAndStoreFolder() throws -> URL? {
        guard let url = chooseFolder() else { return nil }
        try storeBookmark(for: url)
        return url
    }

    func currentFolderURL() -> URL? {
        try? resolveFolderURLFromBookmark()
    }

    // MARK: - Private

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Save Folder"
        panel.message = "Select a folder where VibeCap will save screenshots."
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }

    private func storeBookmark(for folderURL: URL) throws {
        let data = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.saveFolderBookmark = data
    }

    private func resolveFolderURLFromBookmark() throws -> URL? {
        guard let data = SettingsStore.shared.saveFolderBookmark else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                try storeBookmark(for: url)
            }
            return url
        } catch {
            throw SaveError.bookmarkResolveFailed
        }
    }

    private func uniqueURL(in folder: URL, filename: String) -> URL {
        var candidate = folder.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var i = 2
        while true {
            let next = "\(base) \(i).\(ext)"
            candidate = folder.appendingPathComponent(next)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            i += 1
        }
    }

    private static func defaultFilename(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "VC \(f.string(from: now)).png"
    }
}


