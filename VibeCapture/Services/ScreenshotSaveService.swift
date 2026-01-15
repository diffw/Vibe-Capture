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
        guard let data = image.pngData() else { throw SaveError.imageEncodingFailed }

        let folderURL: URL
        if let existing = try resolveFolderURLFromBookmark() {
            folderURL = existing
        } else {
            guard let chosen = chooseFolder() else {
                return false
            }
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
            return true
        } catch {
            throw SaveError.writeFailed(error)
        }
    }

    // MARK: - Save Screenshot (for Save button in modal)

    /// Save screenshot to configured path, or prompt user to choose if not configured
    /// - Returns: true if saved successfully, false if user cancelled
    func saveScreenshot(image: NSImage) throws -> Bool {
        guard let data = image.pngData() else { throw SaveError.imageEncodingFailed }

        let folderURL: URL

        // Check if user has configured a save path
        if let existing = try resolveScreenshotSavePathFromBookmark() {
            folderURL = existing
        } else {
            // No path configured, prompt user to choose
            guard let chosen = chooseSaveLocation(suggestedFilename: Self.defaultFilename()) else {
                return false // User cancelled
            }
            // Save directly to the chosen file URL
            return try saveToURL(data: data, url: chosen)
        }

        // Save to configured folder
        var didStart = false
        didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { folderURL.stopAccessingSecurityScopedResource() }
        }

        let filename = Self.defaultFilename()
        let url = uniqueURL(in: folderURL, filename: filename)

        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            throw SaveError.writeFailed(error)
        }
    }

    /// Resolve the screenshot save path from bookmark
    private func resolveScreenshotSavePathFromBookmark() throws -> URL? {
        guard let data = SettingsStore.shared.screenshotSavePathBookmark else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                try storeScreenshotSavePathBookmark(for: url)
            }
            return url
        } catch {
            throw SaveError.bookmarkResolveFailed
        }
    }

    /// Store screenshot save path bookmark
    func storeScreenshotSavePathBookmark(for folderURL: URL) throws {
        let data = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.screenshotSavePathBookmark = data
        SettingsStore.shared.screenshotSavePath = folderURL.path
    }

    /// Choose and store screenshot save folder
    func chooseAndStoreScreenshotSaveFolder() throws -> URL? {
        guard let url = chooseFolder(title: "Choose Screenshot Save Folder",
                                     message: "Select a folder where screenshots will be saved when you click Save.") else {
            return nil
        }
        try storeScreenshotSavePathBookmark(for: url)
        return url
    }

    /// Get current screenshot save folder URL
    func currentScreenshotSaveFolderURL() -> URL? {
        try? resolveScreenshotSavePathFromBookmark()
    }

    /// Open save panel for user to choose save location
    private func chooseSaveLocation(suggestedFilename: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Screenshot"
        panel.message = "Choose where to save your screenshot."
        panel.prompt = "Save"
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        return url
    }

    /// Save data to a specific URL
    private func saveToURL(data: Data, url: URL) throws -> Bool {
        do {
            try data.write(to: url, options: [.atomic])
            return true
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

    private func chooseFolder(title: String = "Choose Save Folder",
                              message: String = "Select a folder where Vibe Capture will save screenshots.") -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
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


