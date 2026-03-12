import AppKit
import ImageIO
import UniformTypeIdentifiers

extension Notification.Name {
    static let libraryContentDidChange = Notification.Name("LibraryContentDidChange")
}

enum SaveError: LocalizedError {
    case noFolderSelected
    case bookmarkResolveFailed
    case imageEncodingFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noFolderSelected:
            return L("error.no_folder_selected")
        case .bookmarkResolveFailed:
            return L("error.folder_access_failed")
        case .imageEncodingFailed:
            return L("error.image_encoding_failed")
        case .writeFailed(let err):
            return L("error.save_failed", err.localizedDescription)
        }
    }
}

final class ScreenshotSaveService {
    static let shared = ScreenshotSaveService()
    private init() {}

    /// Save to an already-resolved (security-scoped) folder URL.
    /// - Important: This never prompts (safe for background queues / auto-save).
    func saveToKnownFolderAndReturnURL(cgImage: CGImage, folderURL: URL) throws -> URL {
        guard let data = pngData(from: cgImage) else { throw SaveError.imageEncodingFailed }
        return try writePNGData(data, to: folderURL)
    }

    /// Convenience wrapper for UI-thread callers.
    func saveToKnownFolderAndReturnURL(image: NSImage, folderURL: URL) throws -> URL {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw SaveError.imageEncodingFailed
        }
        return try saveToKnownFolderAndReturnURL(cgImage: cgImage, folderURL: folderURL)
    }

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
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = pngData(from: cgImage)
        else { throw SaveError.imageEncodingFailed }

        let folderURL: URL
        let existingFolderURL: URL?
        do {
            existingFolderURL = try resolveFolderURLFromBookmark()
        } catch {
            // If the bookmark is stale/invalid, treat it as "not configured" and re-prompt.
            AppLog.log(.warn, "save", "Failed to resolve save folder bookmark, will prompt user. error=\(error.localizedDescription)")
            existingFolderURL = nil
        }

        if let existingFolderURL {
            folderURL = existingFolderURL
        } else {
            guard let chosen = chooseFolder() else { return nil }
            folderURL = chosen
            try storeBookmark(for: folderURL)
        }

        return try writePNGData(data, to: folderURL)
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
        panel.title = L("panel.choose_folder.title")
        panel.message = L("panel.choose_folder.message")
        panel.prompt = L("button.choose")
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

    private func writePNGData(_ data: Data, to folderURL: URL) throws -> URL {
        var didStart = false
        didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { folderURL.stopAccessingSecurityScopedResource() }
        }

        let filename = Self.defaultFilename()
        let url = uniqueURL(in: folderURL, filename: filename)

        do {
            try data.write(to: url, options: [.atomic])
            NotificationCenter.default.post(
                name: .libraryContentDidChange,
                object: nil,
                userInfo: ["reason": "save", "url": url]
            )
            return url
        } catch {
            throw SaveError.writeFailed(error)
        }
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

    private func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }
        return data as Data
    }
}

enum LibraryServiceError: LocalizedError {
    case folderNotConfigured
    case failedToEnumerate(Error)
    case failedToDecodeKeepState(Error)
    case failedToPersistKeepState(Error)
    case failedToMoveToTrash(Error)
    case failedToLoadImage

    var errorDescription: String? {
        switch self {
        case .folderNotConfigured:
            return "No screenshot folder selected."
        case .failedToEnumerate(let error):
            return "Failed to read screenshot folder: \(error.localizedDescription)"
        case .failedToDecodeKeepState(let error):
            return "Failed to read Keep state: \(error.localizedDescription)"
        case .failedToPersistKeepState(let error):
            return "Failed to save Keep state: \(error.localizedDescription)"
        case .failedToMoveToTrash(let error):
            return "Failed to move screenshot to Trash: \(error.localizedDescription)"
        case .failedToLoadImage:
            return "Failed to load image from file."
        }
    }
}

struct LibraryItem: Equatable {
    let url: URL
    let createdAt: Date
    let fileSizeBytes: Int64
    var isKept: Bool
}

final class KeepMarkerService {
    static let shared = KeepMarkerService()

    private struct Payload: Codable {
        var kept: [String]
    }

    private let keepFileName = ".vibecap-kept.json"
    private let fileManager = FileManager.default

    private init() {}

    func isKept(_ fileURL: URL) -> Bool {
        let folderURL = resolvedFolderURL(for: fileURL.deletingLastPathComponent())
        let set = keptFileNames(in: folderURL)
        return set.contains(fileURL.lastPathComponent)
    }

    func setKept(_ kept: Bool, for fileURL: URL) throws {
        let folderURL = resolvedFolderURL(for: fileURL.deletingLastPathComponent())
        var current = keptFileNames(in: folderURL)
        if kept {
            current.insert(fileURL.lastPathComponent)
        } else {
            current.remove(fileURL.lastPathComponent)
        }
        try persistKeptFileNames(current, in: folderURL)
        NotificationCenter.default.post(
            name: .libraryContentDidChange,
            object: nil,
            userInfo: ["reason": "keep", "url": fileURL, "isKept": kept]
        )
    }

    func keptFileNames(in folderURL: URL) -> Set<String> {
        let effectiveFolderURL = resolvedFolderURL(for: folderURL)
        do {
            return try withSecurityScopedAccess(to: effectiveFolderURL) {
                let markerURL = effectiveFolderURL.appendingPathComponent(keepFileName)
                guard fileManager.fileExists(atPath: markerURL.path) else {
                    return []
                }
                let data = try Data(contentsOf: markerURL)
                let payload = try JSONDecoder().decode(Payload.self, from: data)
                return Set(payload.kept)
            }
        } catch {
            AppLog.log(.warn, "library", "Failed to read Keep marker file: \(error.localizedDescription)")
            return []
        }
    }

    private func persistKeptFileNames(_ values: Set<String>, in folderURL: URL) throws {
        let effectiveFolderURL = resolvedFolderURL(for: folderURL)
        do {
            try withSecurityScopedAccess(to: effectiveFolderURL) {
                let markerURL = effectiveFolderURL.appendingPathComponent(keepFileName)
                let payload = Payload(kept: Array(values).sorted())
                let data = try JSONEncoder().encode(payload)
                try data.write(to: markerURL, options: .atomic)
            }
        } catch {
            throw LibraryServiceError.failedToPersistKeepState(error)
        }
    }

    private func withSecurityScopedAccess<T>(to folderURL: URL, work: () throws -> T) throws -> T {
        let didStart = folderURL.startAccessingSecurityScopedResource()
        if !didStart {
            AppLog.log(.warn, "library", "Security scope not granted for Keep marker path=\(folderURL.path)")
        }
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }

    private func resolvedFolderURL(for folderURL: URL) -> URL {
        guard let bookmarkedFolderURL = ScreenshotSaveService.shared.currentFolderURL() else {
            return folderURL
        }
        if bookmarkedFolderURL.standardizedFileURL.path == folderURL.standardizedFileURL.path {
            return bookmarkedFolderURL
        }
        return folderURL
    }
}

final class LibraryFileService {
    static let shared = LibraryFileService()

    private let fileManager = FileManager.default
    private let keepService: KeepMarkerService

    init(keepService: KeepMarkerService = .shared) {
        self.keepService = keepService
    }

    func currentFolderURL() -> URL? {
        ScreenshotSaveService.shared.currentFolderURL()
    }

    func listItems(filter: LibraryFilterMode) throws -> [LibraryItem] {
        guard let folderURL = currentFolderURL() else {
            throw LibraryServiceError.folderNotConfigured
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw LibraryServiceError.failedToEnumerate(error)
        }

        let keptNames = keepService.keptFileNames(in: folderURL)
        let allowedExtensions = Set(["png", "jpg", "jpeg"])
        var items: [LibraryItem] = []
        items.reserveCapacity(urls.count)

        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }

            let values = try? url.resourceValues(forKeys: resourceKeys)
            if values?.isRegularFile == false { continue }

            let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date.distantPast
            let fileSize = Int64(values?.fileSize ?? 0)
            let isKept = keptNames.contains(url.lastPathComponent)
            if filter == .kept && !isKept {
                continue
            }
            items.append(
                LibraryItem(
                    url: url,
                    createdAt: createdAt,
                    fileSizeBytes: fileSize,
                    isKept: isKept
                )
            )
        }

        return items.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func loadImage(for item: LibraryItem) throws -> NSImage {
        let fallbackFolderURL = item.url.deletingLastPathComponent()
        let scopedFolderURL = resolvedFolderURL(for: fallbackFolderURL)
        // Re-resolve the scoped folder URL from bookmark, then build a child URL from it.
        // URLs captured during directory enumeration may no longer have active access
        // when the collection view later tries to decode thumbnails.
        let scopedFileURL = scopedFolderURL.appendingPathComponent(item.url.lastPathComponent)

        let didStart = scopedFolderURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                scopedFolderURL.stopAccessingSecurityScopedResource()
            }
        }

        // Read bytes while scope is active. `NSImage(contentsOf:)` may defer decoding
        // until draw time, which can happen after scope is closed and produce blanks.
        let data = (try? Data(contentsOf: scopedFileURL)) ?? (try? Data(contentsOf: item.url))
        guard let data, let image = NSImage(data: data) else {
            AppLog.log(.warn, "library", "Failed to decode image file=\(item.url.path)")
            throw LibraryServiceError.failedToLoadImage
        }
        return image
    }

    private func resolvedFolderURL(for folderURL: URL) -> URL {
        guard let bookmarkedFolderURL = currentFolderURL() else {
            return folderURL
        }
        if bookmarkedFolderURL.standardizedFileURL.path == folderURL.standardizedFileURL.path {
            return bookmarkedFolderURL
        }
        return folderURL
    }
}

final class TrashService {
    static let shared = TrashService()
    private let fileManager = FileManager.default

    private init() {}

    func moveToTrash(_ fileURL: URL) throws {
        let parentURL = resolvedFolderURL(for: fileURL.deletingLastPathComponent())
        let resolvedFileURL = parentURL.appendingPathComponent(fileURL.lastPathComponent)
        let didStart = parentURL.startAccessingSecurityScopedResource()
        if !didStart {
            AppLog.log(.warn, "library", "Security scope not granted for Trash path=\(parentURL.path)")
        }
        defer {
            if didStart {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try fileManager.trashItem(at: resolvedFileURL, resultingItemURL: nil)
            NotificationCenter.default.post(
                name: .libraryContentDidChange,
                object: nil,
                userInfo: ["reason": "trash", "url": resolvedFileURL]
            )
        } catch {
            throw LibraryServiceError.failedToMoveToTrash(error)
        }
    }

    private func resolvedFolderURL(for folderURL: URL) -> URL {
        guard let bookmarkedFolderURL = ScreenshotSaveService.shared.currentFolderURL() else {
            return folderURL
        }
        if bookmarkedFolderURL.standardizedFileURL.path == folderURL.standardizedFileURL.path {
            return bookmarkedFolderURL
        }
        return folderURL
    }
}

struct AutoCleanupSummary {
    let scannedCount: Int
    let keptCount: Int
    let removedCount: Int
    let freedBytes: Int64
    let errors: [String]
}

final class AutoCleanupService {
    static let shared = AutoCleanupService()

    private let fileService: LibraryFileService
    private let trashService: TrashService

    init(
        fileService: LibraryFileService = .shared,
        trashService: TrashService = .shared
    ) {
        self.fileService = fileService
        self.trashService = trashService
    }

    func performCleanup(now: Date = Date()) -> AutoCleanupSummary {
        guard SettingsStore.shared.autoCleanupEnabled else {
            return AutoCleanupSummary(scannedCount: 0, keptCount: 0, removedCount: 0, freedBytes: 0, errors: [])
        }

        let allItems: [LibraryItem]
        do {
            allItems = try fileService.listItems(filter: .all)
        } catch {
            return AutoCleanupSummary(scannedCount: 0, keptCount: 0, removedCount: 0, freedBytes: 0, errors: [error.localizedDescription])
        }

        let intervalRaw = SettingsStore.shared.autoCleanupIntervalDays
        let intervalOption = CleanupIntervalOption(rawValue: intervalRaw) ?? .default
        let cutoff = intervalOption.cutoffDate(from: now)

        var keptCount = 0
        var removedCount = 0
        var freedBytes: Int64 = 0
        var errors: [String] = []

        for item in allItems {
            if item.isKept {
                keptCount += 1
                continue
            }
            guard item.createdAt <= cutoff else { continue }

            do {
                try trashService.moveToTrash(item.url)
                removedCount += 1
                freedBytes += item.fileSizeBytes
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        SettingsStore.shared.autoCleanupLastRunAt = now
        return AutoCleanupSummary(
            scannedCount: allItems.count,
            keptCount: keptCount,
            removedCount: removedCount,
            freedBytes: freedBytes,
            errors: errors
        )
    }
}

final class CleanupSchedulerService {
    static let shared = CleanupSchedulerService()

    private var timer: Timer?
    private let autoCleanupService: AutoCleanupService

    init(autoCleanupService: AutoCleanupService = .shared) {
        self.autoCleanupService = autoCleanupService
    }

    func start() {
        runCleanup(reason: "launch", ignoreRunGap: true)
        refreshSchedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshSchedule() {
        stop()
        guard SettingsStore.shared.autoCleanupEnabled else { return }
        let option = CleanupIntervalOption(rawValue: SettingsStore.shared.autoCleanupIntervalDays) ?? .default
        let interval = Self.pollingInterval(for: option)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runCleanup(reason: "timer", ignoreRunGap: false)
        }
        AppLog.log(.info, "cleanup", "scheduler interval_s=\(Int(interval)) option=\(option.label)")
    }

    @discardableResult
    func runCleanup(reason: String, ignoreRunGap: Bool) -> AutoCleanupSummary? {
        guard SettingsStore.shared.autoCleanupEnabled else { return nil }
        let option = CleanupIntervalOption(rawValue: SettingsStore.shared.autoCleanupIntervalDays) ?? .default
        let minRunGap = Self.minimumRunGap(for: option)
        if !ignoreRunGap,
           let lastRun = SettingsStore.shared.autoCleanupLastRunAt,
           Date().timeIntervalSince(lastRun) < minRunGap {
            return nil
        }

        let summary = autoCleanupService.performCleanup()
        AppLog.log(
            .info,
            "cleanup",
            "run reason=\(reason) scanned=\(summary.scannedCount) kept=\(summary.keptCount) removed=\(summary.removedCount) errors=\(summary.errors.count)"
        )

        if summary.removedCount > 0 {
            let freed = ByteCountFormatter.string(fromByteCount: summary.freedBytes, countStyle: .file)
            HUDService.shared.show(
                message: "Auto cleanup removed \(summary.removedCount) screenshot(s), freed \(freed).",
                style: .info,
                duration: 2.0
            )
        } else if !summary.errors.isEmpty {
            HUDService.shared.show(
                message: "Auto cleanup encountered \(summary.errors.count) issue(s).",
                style: .error,
                duration: 2.0
            )
        }

        return summary
    }

    static func minimumRunGap(for option: CleanupIntervalOption) -> TimeInterval {
        switch option {
        case .second5:
            return 5
        case .second30:
            return 30
        case .minute1:
            return 60
        case .minute5:
            return 300
        case .day1, .day7, .day15, .day30, .day60:
            return 60 * 10
        }
    }

    static func pollingInterval(for option: CleanupIntervalOption) -> TimeInterval {
        switch option {
        case .second5:
            return 1
        case .second30:
            return 5
        case .minute1:
            return 10
        case .minute5:
            return 30
        case .day1, .day7, .day15, .day30, .day60:
            return 60 * 60
        }
    }
}


