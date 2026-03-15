import AppKit
import CommonCrypto

final class ThumbnailService {
    static let shared = ThumbnailService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let diskCacheURL: URL
    private let generationQueue = OperationQueue()
    private let fileManager = FileManager.default

    static let maxLongestEdge: CGFloat = 400
    static let jpegQuality: CGFloat = 0.75

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.vibecap"
        diskCacheURL = caches
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.totalCostLimit = 50 * 1024 * 1024
        generationQueue.maxConcurrentOperationCount = 2
        generationQueue.qualityOfService = .userInitiated
    }

    func thumbnail(
        for item: LibraryItem,
        completion: @escaping (NSImage?) -> Void
    ) {
        let key = cacheKey(for: item)
        let nsKey = key as NSString

        if let cached = memoryCache.object(forKey: nsKey) {
            completion(cached)
            return
        }

        generationQueue.addOperation { [weak self] in
            guard let self else { return }
            let image = self.loadOrGenerate(item: item, key: key, nsKey: nsKey)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func evictAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Internal (visible for testing)

    func cacheKey(for item: LibraryItem) -> String {
        Self.cacheKey(path: item.url.path, modDate: item.createdAt)
    }

    static func cacheKey(path: String, modDate: Date) -> String {
        let raw = "\(path)|\(modDate.timeIntervalSince1970)"
        return sha256(raw)
    }

    static func downsample(_ source: NSImage, maxEdge: CGFloat) -> NSImage? {
        let srcSize = source.size
        guard srcSize.width > 0, srcSize.height > 0 else { return nil }

        let longestEdge = max(srcSize.width, srcSize.height)
        if longestEdge <= maxEdge {
            return source
        }

        let scale = maxEdge / longestEdge
        let newWidth = Int(round(srcSize.width * scale))
        let newHeight = Int(round(srcSize.height * scale))

        guard let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        guard let ctx = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgSource, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let cgThumb = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgThumb, size: NSSize(width: newWidth, height: newHeight))
    }

    // MARK: - Private

    private func loadOrGenerate(item: LibraryItem, key: String, nsKey: NSString) -> NSImage? {
        if let diskImage = loadFromDisk(key: key) {
            let cost = estimateCost(diskImage)
            memoryCache.setObject(diskImage, forKey: nsKey, cost: cost)
            return diskImage
        }
        return generateAndCache(item: item, key: key, nsKey: nsKey)
    }

    private func loadFromDisk(key: String) -> NSImage? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }
        return image
    }

    private func generateAndCache(item: LibraryItem, key: String, nsKey: NSString) -> NSImage? {
        let fileService = LibraryFileService.shared
        guard let fullImage = try? fileService.loadImage(for: item) else {
            return nil
        }

        guard let thumb = Self.downsample(fullImage, maxEdge: Self.maxLongestEdge) else {
            return nil
        }

        let cost = estimateCost(thumb)
        memoryCache.setObject(thumb, forKey: nsKey, cost: cost)

        if let jpegData = jpegData(from: thumb) {
            let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
            try? jpegData.write(to: fileURL, options: .atomic)
        }

        return thumb
    }

    private func jpegData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: Self.jpegQuality])
    }

    private func estimateCost(_ image: NSImage) -> Int {
        let s = image.size
        return Int(s.width * s.height * 4)
    }

    private static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
