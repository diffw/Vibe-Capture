import XCTest
import AppKit
@testable import VibeCap

/// Performance tests for ThumbnailService operations.
final class ThumbnailPerformanceTests: XCTestCase {

    private let fileManager = FileManager.default
    private var temporaryFolderURL: URL!
    private var originalBookmark: Data?

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryFolderURL = fileManager.temporaryDirectory
            .appendingPathComponent("vibecap-thumb-perf-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)

        originalBookmark = SettingsStore.shared.saveFolderBookmark
        let bookmark = try temporaryFolderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.saveFolderBookmark = bookmark
    }

    override func tearDownWithError() throws {
        SettingsStore.shared.saveFolderBookmark = originalBookmark
        if let temporaryFolderURL {
            try? fileManager.removeItem(at: temporaryFolderURL)
        }
        temporaryFolderURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Downsample Performance

    func test_perf_downsample2KImage_executionTime() throws {
        let source = makeTestImage(width: 2560, height: 1440)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = ThumbnailService.downsample(source, maxEdge: ThumbnailService.maxLongestEdge)
        }
    }

    func test_perf_downsample5KImage_executionTime() throws {
        let source = makeTestImage(width: 5120, height: 2880)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = ThumbnailService.downsample(source, maxEdge: ThumbnailService.maxLongestEdge)
        }
    }

    // MARK: - Full Thumbnail Generation (file read + downsample + JPEG encode + disk write)

    func test_perf_thumbnailFullGeneration_executionTime() throws {
        let url = try writeImage(named: "perf-full.png", width: 2560, height: 1440)
        let fileService = LibraryFileService()
        let items = try fileService.listItems(filter: .all)
        guard let item = items.first(where: { $0.url.lastPathComponent == "perf-full.png" }) else {
            XCTFail("Item not found")
            return
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let service = ThumbnailService()
            let expectation = expectation(description: "gen")
            service.thumbnail(for: item) { _ in expectation.fulfill() }
            wait(for: [expectation], timeout: 30.0)
            service.evictAll()
        }
    }

    // MARK: - Memory Cache Hit Performance

    func test_perf_thumbnailMemoryCacheHit_executionTime() throws {
        let url = try writeImage(named: "perf-cache.png", width: 1920, height: 1080)
        let fileService = LibraryFileService()
        let items = try fileService.listItems(filter: .all)
        guard let item = items.first(where: { $0.url.lastPathComponent == "perf-cache.png" }) else {
            XCTFail("Item not found")
            return
        }

        let service = ThumbnailService()
        let warmup = expectation(description: "warmup")
        service.thumbnail(for: item) { _ in warmup.fulfill() }
        wait(for: [warmup], timeout: 10.0)

        measure(metrics: [XCTClockMetric()]) {
            var img: NSImage?
            service.thumbnail(for: item) { image in
                img = image
            }
            XCTAssertNotNil(img, "Memory cache hit should be synchronous")
        }

        service.evictAll()
    }

    // MARK: - countImageFiles vs listItems Performance

    func test_perf_countImageFiles_vs_listItemsAll() throws {
        for i in 0..<50 {
            try writeImage(named: "bulk-\(i).png", width: 200, height: 200)
        }

        let fileService = LibraryFileService()

        var listTime: Double = 0
        var countTime: Double = 0

        let iterations = 5
        for _ in 0..<iterations {
            let t1 = CFAbsoluteTimeGetCurrent()
            _ = try fileService.listItems(filter: .all).count
            listTime += CFAbsoluteTimeGetCurrent() - t1

            let t2 = CFAbsoluteTimeGetCurrent()
            _ = try fileService.countImageFiles()
            countTime += CFAbsoluteTimeGetCurrent() - t2
        }

        listTime /= Double(iterations)
        countTime /= Double(iterations)

        print("📊 listItems(.all).count avg: \(String(format: "%.4f", listTime * 1000))ms")
        print("📊 countImageFiles() avg: \(String(format: "%.4f", countTime * 1000))ms")
        XCTAssertLessThan(countTime, listTime, "countImageFiles should be faster than full listItems")
    }

    // MARK: - Helpers

    private func makeTestImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()
        return image
    }

    @discardableResult
    private func writeImage(named name: String, width: CGFloat, height: CGFloat) throws -> URL {
        let url = temporaryFolderURL.appendingPathComponent(name)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemOrange.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        guard let data = image.pngData() else {
            throw LibraryServiceError.failedToLoadImage
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
