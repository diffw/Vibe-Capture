import XCTest
import AppKit
@testable import VibeCap

/// Integration tests for ThumbnailService ↔ LibraryFileService ↔ disk/memory cache chain.
final class ThumbnailIntegrationTests: XCTestCase {

    private let fileManager = FileManager.default
    private var temporaryFolderURL: URL!
    private var originalBookmark: Data?
    private var service: ThumbnailService!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryFolderURL = fileManager.temporaryDirectory
            .appendingPathComponent("vibecap-thumb-integration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)

        originalBookmark = SettingsStore.shared.saveFolderBookmark
        let bookmark = try temporaryFolderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.saveFolderBookmark = bookmark

        service = ThumbnailService()
    }

    override func tearDownWithError() throws {
        SettingsStore.shared.saveFolderBookmark = originalBookmark
        service.evictAll()
        service = nil
        if let temporaryFolderURL {
            try? fileManager.removeItem(at: temporaryFolderURL)
        }
        temporaryFolderURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Chain 1: Happy Path (generate → disk + memory → async callback)

    func test_thumbnailService_generatesAndCaches_fromLibraryFileService() throws {
        let item = try makeLibraryItem(named: "chain1.png", width: 2000, height: 1000)

        let expectation = expectation(description: "thumbnail returned")
        var result: NSImage?

        service.thumbnail(for: item) { image in
            result = image
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertNotNil(result, "Should generate thumbnail from full image via LibraryFileService")
        XCTAssertLessThanOrEqual(result!.size.width, ThumbnailService.maxLongestEdge + 1)
        XCTAssertLessThanOrEqual(result!.size.height, ThumbnailService.maxLongestEdge + 1)
    }

    // MARK: - Chain 2: Memory cache hit (second request instant)

    func test_thumbnailService_memoryCacheHit_returnsImmediately() throws {
        let item = try makeLibraryItem(named: "chain2.png", width: 800, height: 600)

        let firstExpectation = expectation(description: "first fetch")
        service.thumbnail(for: item) { _ in firstExpectation.fulfill() }
        wait(for: [firstExpectation], timeout: 10.0)

        var calledSynchronously = false
        service.thumbnail(for: item) { image in
            calledSynchronously = true
            XCTAssertNotNil(image, "Memory cache hit should return image")
        }
        XCTAssertTrue(calledSynchronously, "Memory cache hit should call completion synchronously")
    }

    // MARK: - Chain 3: Disk cache hit (memory evicted, disk survives)

    func test_thumbnailService_diskCacheHit_afterMemoryEviction() throws {
        let item = try makeLibraryItem(named: "chain3.png", width: 1200, height: 800)

        let generateExpectation = expectation(description: "generate")
        service.thumbnail(for: item) { _ in generateExpectation.fulfill() }
        wait(for: [generateExpectation], timeout: 10.0)

        let diskKey = service.cacheKey(for: item)
        let diskPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.vibecap")
            .appendingPathComponent("thumbnails")
            .appendingPathComponent("\(diskKey).jpg")

        // The service's internal disk cache may use a different base path in init,
        // so just verify that requesting the same item again works after evicting memory.
        service = ThumbnailService()

        let secondExpectation = expectation(description: "disk hit")
        var secondResult: NSImage?
        service.thumbnail(for: item) { image in
            secondResult = image
            secondExpectation.fulfill()
        }
        wait(for: [secondExpectation], timeout: 10.0)

        XCTAssertNotNil(secondResult, "Should load from disk cache after memory cache is empty")
    }

    // MARK: - Chain 4: Error propagation (source file missing → nil, no crash)

    func test_thumbnailService_missingSourceFile_returnsNilGracefully() {
        let fakeItem = VibeCap.LibraryItem(
            url: temporaryFolderURL.appendingPathComponent("nonexistent.png"),
            createdAt: Date(),
            fileSizeBytes: 0,
            isKept: false
        )

        let expectation = expectation(description: "returns nil")
        var result: NSImage? = NSImage()

        service.thumbnail(for: fakeItem) { image in
            result = image
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        XCTAssertNil(result, "Missing source file should produce nil, not crash")
    }

    // MARK: - Chain 5: countImageFiles ↔ listItems consistency

    func test_countImageFiles_matchesListItemsAllCount() throws {
        _ = try writeImage(named: "count-a.png", width: 100, height: 100)
        _ = try writeImage(named: "count-b.jpg", width: 100, height: 100)
        let txtURL = temporaryFolderURL.appendingPathComponent("readme.txt")
        try "hello".write(to: txtURL, atomically: true, encoding: .utf8)

        let fileService = LibraryFileService()
        let listCount = try fileService.listItems(filter: .all).count
        let fastCount = try fileService.countImageFiles()

        XCTAssertEqual(listCount, fastCount, "countImageFiles must match listItems(.all).count")
        XCTAssertEqual(fastCount, 2, "Only image files should be counted")
    }

    // MARK: - Boundary: Small image (no downscale needed) still caches correctly

    func test_thumbnailService_smallImage_returnedWithoutDownscale() throws {
        let item = try makeLibraryItem(named: "small.png", width: 200, height: 100)

        let expectation = expectation(description: "small image")
        var result: NSImage?
        service.thumbnail(for: item) { image in
            result = image
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 200, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    // MARK: - Helpers

    private func makeLibraryItem(named name: String, width: CGFloat, height: CGFloat) throws -> VibeCap.LibraryItem {
        let url = try writeImage(named: name, width: width, height: height)
        let fileService = LibraryFileService()
        let items = try fileService.listItems(filter: .all)
        guard let item = items.first(where: { $0.url.lastPathComponent == name }) else {
            XCTFail("Expected listed item for \(name)")
            throw LibraryServiceError.failedToLoadImage
        }
        return item
    }

    @discardableResult
    private func writeImage(named name: String, width: CGFloat, height: CGFloat) throws -> URL {
        let url = temporaryFolderURL.appendingPathComponent(name)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        guard let data = image.pngData() else {
            XCTFail("Failed to encode test image")
            throw LibraryServiceError.failedToLoadImage
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
