import XCTest
import AppKit
@testable import VibeCap

final class ScreenCropConverterTests: XCTestCase {
    func testCropRectInImagePixels_BottomLeftQuarter_mapsToLowerLeftInRasterSpace() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100) // points
        let selection = CGRect(x: 0, y: 0, width: 50, height: 50) // bottom-left quarter (points)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        XCTAssertEqual(crop, CGRect(x: 0, y: 100, width: 100, height: 100))
    }

    func testCropRectInImagePixels_TopLeftQuarter_mapsToUpperLeftInRasterSpace() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100) // points
        let selection = CGRect(x: 0, y: 50, width: 50, height: 50) // top-left quarter (points)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        XCTAssertEqual(crop, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testCropRectInImagePixels_AppliesScreenOriginOffset() {
        let screenFrame = CGRect(x: 100, y: 200, width: 100, height: 100) // points
        let selection = CGRect(x: 110, y: 210, width: 10, height: 20) // points (global)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        // localPt = (10, 10, 10, 20) -> px = (20, 20, 20, 40) -> yFlip = 200 - (20+40) = 140
        XCTAssertEqual(crop, CGRect(x: 20, y: 140, width: 20, height: 40))
    }

    func testCropRectInImagePixels_ReturnsNilWhenSelectionIsEmptyOrOffscreen() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200)

        XCTAssertNil(ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: CGRect(x: 0, y: 0, width: 0, height: 10),
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        ))

        XCTAssertNil(ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: CGRect(x: -1000, y: -1000, width: 10, height: 10),
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        ))
    }
}

final class SettingsStoreLibraryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var sut: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.vibecap.settings.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        sut = SettingsStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        sut = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testCleanupDefaultsAndPersistence() {
        XCTAssertFalse(sut.autoCleanupEnabled)
        XCTAssertEqual(sut.autoCleanupIntervalDays, CleanupIntervalOption.default.rawValue)
        XCTAssertNil(sut.autoCleanupLastRunAt)

        let now = Date()
        sut.autoCleanupEnabled = true
        sut.autoCleanupIntervalDays = CleanupIntervalOption.day7.rawValue
        sut.autoCleanupLastRunAt = now

        XCTAssertTrue(sut.autoCleanupEnabled)
        XCTAssertEqual(sut.autoCleanupIntervalDays, 7)
        guard let storedDate = sut.autoCleanupLastRunAt else {
            XCTFail("Expected cleanup run date to be persisted.")
            return
        }
        XCTAssertEqual(storedDate.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.01)
    }

    func testCleanupShortIntervalsCanBePersisted() {
        sut.autoCleanupIntervalDays = CleanupIntervalOption.second5.rawValue
        XCTAssertEqual(sut.autoCleanupIntervalDays, CleanupIntervalOption.second5.rawValue)

        sut.autoCleanupIntervalDays = CleanupIntervalOption.second30.rawValue
        XCTAssertEqual(sut.autoCleanupIntervalDays, CleanupIntervalOption.second30.rawValue)

        sut.autoCleanupIntervalDays = CleanupIntervalOption.minute1.rawValue
        XCTAssertEqual(sut.autoCleanupIntervalDays, CleanupIntervalOption.minute1.rawValue)

        sut.autoCleanupIntervalDays = CleanupIntervalOption.minute5.rawValue
        XCTAssertEqual(sut.autoCleanupIntervalDays, CleanupIntervalOption.minute5.rawValue)
    }

    func testCleanupIntervalOptionSecond5CutoffDate() {
        let now = Date()
        let cutoff = CleanupIntervalOption.second5.cutoffDate(from: now)
        XCTAssertEqual(now.timeIntervalSince(cutoff), 5, accuracy: 0.01)
    }

    func testCleanupSchedulerSupportsSecond5Cadence() {
        XCTAssertEqual(CleanupSchedulerService.minimumRunGap(for: .second5), 5)
        XCTAssertEqual(CleanupSchedulerService.pollingInterval(for: .second5), 1)
    }
}

final class LibraryServicesTests: XCTestCase {
    private let fileManager = FileManager.default
    private var temporaryFolderURL: URL!
    private var originalBookmark: Data?
    private var originalCleanupEnabled: Bool = false
    private var originalCleanupInterval: Int = 30

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryFolderURL = fileManager.temporaryDirectory.appendingPathComponent("vibecap-library-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)

        originalBookmark = SettingsStore.shared.saveFolderBookmark
        originalCleanupEnabled = SettingsStore.shared.autoCleanupEnabled
        originalCleanupInterval = SettingsStore.shared.autoCleanupIntervalDays

        let bookmark = try temporaryFolderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.saveFolderBookmark = bookmark
        SettingsStore.shared.autoCleanupEnabled = false
        SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.default.rawValue
        SettingsStore.shared.autoCleanupLastRunAt = nil
    }

    override func tearDownWithError() throws {
        SettingsStore.shared.saveFolderBookmark = originalBookmark
        SettingsStore.shared.autoCleanupEnabled = originalCleanupEnabled
        SettingsStore.shared.autoCleanupIntervalDays = originalCleanupInterval
        SettingsStore.shared.autoCleanupLastRunAt = nil
        if let temporaryFolderURL {
            try? fileManager.removeItem(at: temporaryFolderURL)
        }
        temporaryFolderURL = nil
        try super.tearDownWithError()
    }

    func testKeepMarkerRoundTrip() throws {
        let fileURL = try writeImage(named: "keep-roundtrip.png", daysAgo: 0)
        XCTAssertFalse(KeepMarkerService.shared.isKept(fileURL))

        try KeepMarkerService.shared.setKept(true, for: fileURL)
        XCTAssertTrue(KeepMarkerService.shared.isKept(fileURL))

        try KeepMarkerService.shared.setKept(false, for: fileURL)
        XCTAssertFalse(KeepMarkerService.shared.isKept(fileURL))
    }

    func testSetKeptPostsLibraryContentChangeNotification() throws {
        let fileURL = try writeImage(named: "keep-notification.png", daysAgo: 0)
        let expectation = expectation(forNotification: .libraryContentDidChange, object: nil) { notification in
            guard let reason = notification.userInfo?["reason"] as? String else { return false }
            return reason == "keep"
        }

        try KeepMarkerService.shared.setKept(true, for: fileURL)
        wait(for: [expectation], timeout: 1.0)
    }

    func testLibraryFileServiceCanFilterKeptItems() throws {
        let keptURL = try writeImage(named: "kept-item.png", daysAgo: 0)
        let normalURL = try writeImage(named: "normal-item.png", daysAgo: 0)
        try KeepMarkerService.shared.setKept(true, for: keptURL)

        let service = LibraryFileService()
        let all = try service.listItems(filter: .all)
        let kept = try service.listItems(filter: .kept)

        XCTAssertTrue(all.contains(where: { $0.url == keptURL }))
        XCTAssertTrue(all.contains(where: { $0.url == normalURL }))
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.url, keptURL)
        XCTAssertTrue(kept.first?.isKept == true)
    }

    func testLibraryFileServiceCanLoadImageFromListedItem() throws {
        let targetURL = try writeImage(named: "load-image.png", daysAgo: 0)
        let service = LibraryFileService()
        let items = try service.listItems(filter: .all)
        guard let item = items.first(where: { $0.url == targetURL }) else {
            XCTFail("Expected listed item for test image.")
            return
        }

        let image = try service.loadImage(for: item)
        XCTAssertEqual(image.size.width, 20, accuracy: 0.1)
        XCTAssertEqual(image.size.height, 20, accuracy: 0.1)
    }

    func testCountImageFilesReturnsCorrectCount() throws {
        _ = try writeImage(named: "count-a.png", daysAgo: 0)
        _ = try writeImage(named: "count-b.jpg", daysAgo: 0)
        let txtURL = temporaryFolderURL.appendingPathComponent("readme.txt")
        try "hello".write(to: txtURL, atomically: true, encoding: .utf8)

        let service = LibraryFileService()
        let count = try service.countImageFiles()
        XCTAssertEqual(count, 2)
    }

    func testTrashServiceCanMoveListedItemToTrash() throws {
        let targetURL = try writeImage(named: "trash-item.png", daysAgo: 0)
        let service = LibraryFileService()
        let items = try service.listItems(filter: .all)
        guard let item = items.first(where: { $0.url == targetURL }) else {
            XCTFail("Expected listed item for trash test.")
            return
        }

        try TrashService.shared.moveToTrash(item.url)
        XCTAssertFalse(fileManager.fileExists(atPath: targetURL.path))
    }

    func testTrashServicePostsLibraryContentChangeNotification() throws {
        let targetURL = try writeImage(named: "trash-notification.png", daysAgo: 0)
        let expectation = expectation(forNotification: .libraryContentDidChange, object: nil) { notification in
            guard let reason = notification.userInfo?["reason"] as? String else { return false }
            return reason == "trash"
        }

        try TrashService.shared.moveToTrash(targetURL)
        wait(for: [expectation], timeout: 1.0)
    }

    func testSaveScreenshotPostsLibraryContentChangeNotification() throws {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 20, height: 20)).fill()
        image.unlockFocus()

        let expectation = expectation(forNotification: .libraryContentDidChange, object: nil) { notification in
            guard let reason = notification.userInfo?["reason"] as? String else { return false }
            return reason == "save"
        }

        let savedURL = try ScreenshotSaveService.shared.saveScreenshotAndReturnURL(image: image)
        XCTAssertNotNil(savedURL)
        wait(for: [expectation], timeout: 1.0)
    }

    func testAutoCleanupDisabledReturnsEmptySummary() throws {
        _ = try writeImage(named: "cleanup-disabled.png", daysAgo: 20)
        SettingsStore.shared.autoCleanupEnabled = false

        let summary = AutoCleanupService.shared.performCleanup(now: Date())
        XCTAssertEqual(summary.scannedCount, 0)
        XCTAssertEqual(summary.removedCount, 0)
        XCTAssertTrue(summary.errors.isEmpty)
    }

    func testAutoCleanupSkipsKeptItems() throws {
        let keptURL = try writeImage(named: "cleanup-kept.png", daysAgo: 30)
        _ = try writeImage(named: "cleanup-normal.png", daysAgo: 30)
        try KeepMarkerService.shared.setKept(true, for: keptURL)

        SettingsStore.shared.autoCleanupEnabled = true
        SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.day1.rawValue

        let summary = AutoCleanupService.shared.performCleanup(now: Date())
        XCTAssertEqual(summary.scannedCount, 2)
        XCTAssertEqual(summary.keptCount, 1)
        XCTAssertTrue(fileManager.fileExists(atPath: keptURL.path))
    }

    func testAutoCleanupUsesSecondLevelInterval() throws {
        let now = Date()
        let staleURL = try writeImage(named: "cleanup-30s-stale.png", createdAt: now.addingTimeInterval(-40))
        let freshURL = try writeImage(named: "cleanup-30s-fresh.png", createdAt: now.addingTimeInterval(-10))

        SettingsStore.shared.autoCleanupEnabled = true
        SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.second30.rawValue

        let summary = AutoCleanupService.shared.performCleanup(now: now)
        XCTAssertEqual(summary.scannedCount, 2)
        if summary.errors.isEmpty {
            XCTAssertFalse(fileManager.fileExists(atPath: staleURL.path))
            XCTAssertTrue(fileManager.fileExists(atPath: freshURL.path))
        }
    }

    func testAutoCleanupWithNoFolderProducesError() {
        SettingsStore.shared.saveFolderBookmark = nil
        SettingsStore.shared.autoCleanupEnabled = true

        let summary = AutoCleanupService.shared.performCleanup(now: Date())
        XCTAssertFalse(summary.errors.isEmpty)
    }

    func testCleanupSchedulerSkipsRunWithinSecond5Gap() {
        SettingsStore.shared.autoCleanupEnabled = true
        SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.second5.rawValue
        SettingsStore.shared.autoCleanupLastRunAt = Date()

        let scheduler = CleanupSchedulerService(autoCleanupService: .shared)
        let summary = scheduler.runCleanup(reason: "unit-test", ignoreRunGap: false)
        XCTAssertNil(summary)
    }

    func testCleanupSchedulerRunsAfterSecond5Gap() {
        SettingsStore.shared.autoCleanupEnabled = true
        SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.second5.rawValue
        SettingsStore.shared.autoCleanupLastRunAt = Date().addingTimeInterval(-6)

        let scheduler = CleanupSchedulerService(autoCleanupService: .shared)
        let summary = scheduler.runCleanup(reason: "unit-test", ignoreRunGap: false)
        XCTAssertNotNil(summary)
    }

    private func writeImage(named name: String, daysAgo: Int) throws -> URL {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return try writeImage(named: name, createdAt: date)
    }

    private func writeImage(named name: String, createdAt: Date) throws -> URL {
        let url = temporaryFolderURL.appendingPathComponent(name)
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        guard let data = image.pngData() else {
            XCTFail("Failed to encode image data in test fixture.")
            throw LibraryServiceError.failedToLoadImage
        }
        try data.write(to: url, options: .atomic)

        try? fileManager.setAttributes([.creationDate: createdAt], ofItemAtPath: url.path)
        try? fileManager.setAttributes([.modificationDate: createdAt], ofItemAtPath: url.path)
        return url
    }
}

// MARK: - ThumbnailService Tests

final class ThumbnailServiceTests: XCTestCase {

    func testCacheKey_sameInputsProduceSameKey() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let key1 = ThumbnailService.cacheKey(path: "/tmp/a.png", modDate: date)
        let key2 = ThumbnailService.cacheKey(path: "/tmp/a.png", modDate: date)
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.count, 64, "SHA-256 hex should be 64 chars")
    }

    func testCacheKey_differentPathsProduceDifferentKeys() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let key1 = ThumbnailService.cacheKey(path: "/tmp/a.png", modDate: date)
        let key2 = ThumbnailService.cacheKey(path: "/tmp/b.png", modDate: date)
        XCTAssertNotEqual(key1, key2)
    }

    func testCacheKey_differentDatesProduceDifferentKeys() {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = Date(timeIntervalSince1970: 1_700_000_001)
        let key1 = ThumbnailService.cacheKey(path: "/tmp/a.png", modDate: date1)
        let key2 = ThumbnailService.cacheKey(path: "/tmp/a.png", modDate: date2)
        XCTAssertNotEqual(key1, key2)
    }

    func testDownsample_largeImageIsScaledDown() {
        let source = makeImage(width: 2000, height: 1000)
        let result = ThumbnailService.downsample(source, maxEdge: 400)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 400, accuracy: 1)
        XCTAssertEqual(result!.size.height, 200, accuracy: 1)
    }

    func testDownsample_smallImageIsReturnedUnchanged() {
        let source = makeImage(width: 200, height: 100)
        let result = ThumbnailService.downsample(source, maxEdge: 400)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 200, accuracy: 1)
        XCTAssertEqual(result!.size.height, 100, accuracy: 1)
    }

    func testDownsample_tallImageScalesByHeight() {
        let source = makeImage(width: 500, height: 1000)
        let result = ThumbnailService.downsample(source, maxEdge: 400)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.height, 400, accuracy: 1)
        XCTAssertEqual(result!.size.width, 200, accuracy: 1)
    }

    func testDownsample_exactEdgeIsReturnedUnchanged() {
        let source = makeImage(width: 400, height: 300)
        let result = ThumbnailService.downsample(source, maxEdge: 400)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.size.width, 400, accuracy: 1)
        XCTAssertEqual(result!.size.height, 300, accuracy: 1)
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()
        return image
    }
}

final class CaptureModalWindowControllerTests: XCTestCase {
    func testPreferredWindowLevelInUITestingIsNormal() {
        let level = CaptureModalWindowController.preferredWindowLevel(isUITesting: true)
        XCTAssertEqual(level.rawValue, NSWindow.Level.normal.rawValue)
    }

    func testPreferredWindowLevelInProductionIsMainMenu() {
        let level = CaptureModalWindowController.preferredWindowLevel(isUITesting: false)
        XCTAssertEqual(level.rawValue, NSWindow.Level.mainMenu.rawValue)
    }
}

final class LibraryWindowControllerTests: XCTestCase {
    func testInit_ConfiguresMinimumContentSize() {
        // Arrange
        let sut = LibraryWindowController()

        // Act
        let minSize = sut.window?.contentMinSize

        // Assert
        XCTAssertEqual(minSize, LibraryWindowController.minimumContentSize)
    }

    func testMinimumContentSize_DoesNotExceedDefaultSize() {
        // Arrange
        let defaultSize = LibraryWindowController.defaultContentSize
        let minimumSize = LibraryWindowController.minimumContentSize

        // Act & Assert
        XCTAssertLessThanOrEqual(minimumSize.width, defaultSize.width)
        XCTAssertLessThanOrEqual(minimumSize.height, defaultSize.height)
    }

    func testCollectionView_DoesNotInstallDoubleClickGestureRecognizer() {
        // Arrange
        let sut = LibraryWindowController()
        guard let rootView = sut.window?.contentViewController?.view else {
            XCTFail("Expected library content view to be available.")
            return
        }
        guard let collectionView = findCollectionView(in: rootView) else {
            XCTFail("Expected NSCollectionView in library window.")
            return
        }
        let hasDoubleClickGestureRecognizer = collectionView.gestureRecognizers
            .compactMap { $0 as? NSClickGestureRecognizer }
            .contains(where: { $0.numberOfClicksRequired == 2 })

        // Act & Assert
        XCTAssertFalse(hasDoubleClickGestureRecognizer)
    }

    func testCollectionView_AllowsMultipleSelection() throws {
        try withLibraryWindowHavingItems { _, collectionView in
            XCTAssertTrue(collectionView.allowsMultipleSelection)
        }
    }

    func testLibraryToolbar_DoesNotContainRefreshButton() {
        let sut = LibraryWindowController()
        guard let rootView = sut.window?.contentViewController?.view else {
            XCTFail("Expected library content view to be available.")
            return
        }

        XCTAssertNil(findButton(titled: "Refresh", in: rootView))
    }

    func testCancelButton_ClearsCurrentSelection() throws {
        try withLibraryWindowHavingItems { sut, collectionView in
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: [])
            XCTAssertEqual(collectionView.selectionIndexPaths.count, 1)

            guard
                let rootView = sut.window?.contentViewController?.view,
                let cancelButton = findButton(identifier: "library.button.cancel", in: rootView)
            else {
                XCTFail("Expected Cancel button in library toolbar.")
                return
            }

            guard let action = cancelButton.action else {
                XCTFail("Expected Cancel button action.")
                return
            }
            _ = NSApp.sendAction(action, to: cancelButton.target, from: cancelButton)
            XCTAssertTrue(collectionView.selectionIndexPaths.isEmpty)
        }
    }

    func testCancelButton_WhenSelectionExists_IsPositionedOnLeadingSide() throws {
        try withLibraryWindowHavingItems { sut, collectionView in
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: [])
            guard
                let rootView = sut.window?.contentViewController?.view,
                let cancelButton = findButton(identifier: "library.button.cancel", in: rootView)
            else {
                XCTFail("Expected Cancel button in library toolbar.")
                return
            }

            rootView.layoutSubtreeIfNeeded()
            let cancelFrame = cancelButton.convert(cancelButton.bounds, to: rootView)
            XCTAssertLessThan(cancelFrame.minX, rootView.bounds.midX)
        }
    }

    func testSelectionToolbar_PlacesCopyButtonBeforeOpenButton() throws {
        try withLibraryWindowHavingItems { sut, collectionView in
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: [])
            guard
                let rootView = sut.window?.contentViewController?.view,
                let copyButton = findButton(identifier: "library.button.copy", in: rootView),
                let openButton = findButton(identifier: "library.button.open", in: rootView)
            else {
                XCTFail("Expected Copy and Open buttons in selection toolbar.")
                return
            }

            rootView.layoutSubtreeIfNeeded()
            let copyFrame = copyButton.convert(copyButton.bounds, to: rootView)
            let openFrame = openButton.convert(openButton.bounds, to: rootView)
            XCTAssertLessThan(copyFrame.minX, openFrame.minX)
        }
    }

    func testFilterControl_DisplaysItemCountsInLabels() throws {
        try withLibraryWindowHavingItems { sut, _ in
            guard
                let rootView = sut.window?.contentViewController?.view,
                let filterControl = findSegmentedControl(identifier: "library.control.filter", in: rootView)
            else {
                XCTFail("Expected filter segmented control in library toolbar.")
                return
            }
            XCTAssertEqual(filterControl.label(forSegment: 0), "All (2)")
            XCTAssertEqual(filterControl.label(forSegment: 1), "Kept (0)")
        }
    }

    func testResolveLibrarySelectionCountText_UsesExpectedFormat() {
        XCTAssertEqual(resolveLibrarySelectionCountText(1), "1 selected")
        XCTAssertEqual(resolveLibrarySelectionCountText(3), "3 selected")
    }

    func testResolveLibraryFilterLabelState_FormatsCounts() {
        let labels = resolveLibraryFilterLabelState(allCount: 12, keptCount: 3)
        XCTAssertEqual(labels.allLabel, "All (12)")
        XCTAssertEqual(labels.keptLabel, "Kept (3)")
    }

    func testResolveLibraryItemBorderColor_UsesNeutralBorderForKeptWhenNotSelected() {
        XCTAssertEqual(
            resolveLibraryItemBorderColor(isSelected: false, isKept: true),
            .separatorColor
        )
    }

    func testResolveLibraryItemBorderColor_UsesAccentWhenSelected() {
        XCTAssertEqual(
            resolveLibraryItemBorderColor(isSelected: true, isKept: true),
            .controlAccentColor
        )
    }

    func testResolveLibraryKeepBadgeStyle_UsesCircularIconBadge() {
        let style = resolveLibraryKeepBadgeStyle()
        XCTAssertEqual(style.symbolName, "flag.fill")
        XCTAssertEqual(style.iconTintColor, .white)
        XCTAssertEqual(style.backgroundColor, .systemOrange)
    }

    func testResolveLibraryKeepActionButtonStyle_UsesWhiteBackgroundAndDarkForeground() {
        let style = resolveLibraryKeepActionButtonStyle()
        XCTAssertEqual(style.symbolName, "flag.fill")
        XCTAssertEqual(style.iconTintColor, .darkGray)
        XCTAssertEqual(style.backgroundColor, .white)
    }

    func testResolveLibraryKeepActionButtonStyle_MatchesBadgeBorderStyle() {
        let badgeStyle = resolveLibraryKeepBadgeStyle()
        let actionStyle = resolveLibraryKeepActionButtonStyle()
        XCTAssertEqual(actionStyle.borderColor, badgeStyle.borderColor)
    }

    func testResolveLibraryKeepControlMetrics_KeepsIconSizesConsistentAcrossStates() {
        let metrics = resolveLibraryKeepControlMetrics()
        XCTAssertEqual(metrics.keepActionButtonHeight, 28, accuracy: 0.001)
        XCTAssertEqual(metrics.keptBadgeDiameter, 28, accuracy: 0.001)
        XCTAssertEqual(metrics.keepActionButtonHeight, metrics.keptBadgeDiameter, accuracy: 0.001)
    }

    func testResolveLibraryKeepTooltipText_ForUnkeptItem_ShowsKeep() {
        XCTAssertEqual(resolveLibraryKeepTooltipText(isKept: false), "Keep")
    }

    func testResolveLibraryKeepTooltipText_ForKeptItem_ShowsUnkeep() {
        XCTAssertEqual(resolveLibraryKeepTooltipText(isKept: true), "Unkeep")
    }

    func testResolveLibraryShouldScheduleReload_WhenSuppressedKeepNotification_ReturnsFalse() {
        let shouldSchedule = resolveLibraryShouldScheduleReload(
            notificationReason: "keep",
            suppressLocalKeepReload: true
        )
        XCTAssertFalse(shouldSchedule)
    }

    func testResolveLibraryShouldScheduleReload_WhenKeepNotificationNotSuppressed_ReturnsTrue() {
        let shouldSchedule = resolveLibraryShouldScheduleReload(
            notificationReason: "keep",
            suppressLocalKeepReload: false
        )
        XCTAssertTrue(shouldSchedule)
    }

    func testResolveLibraryShouldScheduleReload_WhenReasonIsNotKeep_ReturnsTrue() {
        let shouldSchedule = resolveLibraryShouldScheduleReload(
            notificationReason: "delete",
            suppressLocalKeepReload: true
        )
        XCTAssertTrue(shouldSchedule)
    }

    func testResolveLibraryKeepControlState_ForKeptItem_ShowsKeptBadge() {
        let state = resolveLibraryKeepControlState(
            isKept: true,
            isHoveredOnPreview: false,
            isSelected: false
        )
        XCTAssertEqual(state, .keptBadge)
    }

    func testResolveLibraryKeepControlState_ForHoveredUnkeptItem_ShowsKeepActionButton() {
        let state = resolveLibraryKeepControlState(
            isKept: false,
            isHoveredOnPreview: true,
            isSelected: false
        )
        XCTAssertEqual(state, .keepActionButton)
    }

    func testResolveLibraryKeepControlState_ForSelectedUnkeptItem_ShowsKeepActionButton() {
        let state = resolveLibraryKeepControlState(
            isKept: false,
            isHoveredOnPreview: false,
            isSelected: true
        )
        XCTAssertEqual(state, .keepActionButton)
    }

    func testResolveLibraryKeepControlState_ForIdleUnkeptItem_HidesControls() {
        let state = resolveLibraryKeepControlState(
            isKept: false,
            isHoveredOnPreview: false,
            isSelected: false
        )
        XCTAssertEqual(state, .hidden)
    }

    func testResolveLibraryKeyboardAction_CommandDeleteTriggersDelete() {
        XCTAssertEqual(
            resolveLibraryKeyboardAction(keyCode: 51, modifierFlags: [.command]),
            .deleteSelection
        )
        XCTAssertEqual(
            resolveLibraryKeyboardAction(keyCode: 117, modifierFlags: [.command]),
            .deleteSelection
        )
    }

    func testResolveLibraryKeyboardAction_CommandCTriggersCopySelection() {
        XCTAssertEqual(
            resolveLibraryKeyboardAction(keyCode: 8, modifierFlags: [.command]),
            .copySelection
        )
    }

    func testResolveLibraryKeyboardAction_SpaceTriggersSpaceOpen() {
        XCTAssertEqual(resolveLibraryKeyboardAction(keyCode: 49, modifierFlags: []), .openFromSpace)
    }

    func testResolveLibraryKeyboardAction_ReturnTriggersReturnOpen() {
        XCTAssertEqual(resolveLibraryKeyboardAction(keyCode: 36, modifierFlags: []), .openFromReturn)
    }

    func testResolveLibraryKeyboardAction_OtherKeysReturnNone() {
        XCTAssertEqual(resolveLibraryKeyboardAction(keyCode: 123, modifierFlags: []), .none)
        XCTAssertEqual(resolveLibraryKeyboardAction(keyCode: 0, modifierFlags: [.command]), .none)
    }

    func testResolveLibraryPrimarySelectedIndex_ReturnsFirstForSingleSelection() {
        let index = resolveLibraryPrimarySelectedIndex(selectedIndexes: [3], selectedItemCount: 1)
        XCTAssertEqual(index, 3)
    }

    func testResolveLibraryPrimarySelectedIndex_ReturnsNilWhenNotSingleSelection() {
        XCTAssertNil(resolveLibraryPrimarySelectedIndex(selectedIndexes: [3, 4], selectedItemCount: 2))
        XCTAssertNil(resolveLibraryPrimarySelectedIndex(selectedIndexes: [], selectedItemCount: 0))
    }

    func testResolveImageViewerCloseAction_WhenOpenedBySpace_AllowsSpaceAndEsc() {
        XCTAssertTrue(resolveImageViewerCloseAction(for: 49, entryMode: .spaceToggleClosable))
        XCTAssertTrue(resolveImageViewerCloseAction(for: 53, entryMode: .spaceToggleClosable))
    }

    func testResolveImageViewerCloseAction_WhenOpenedByDoubleClick_DoesNotCloseOnSpace() {
        XCTAssertFalse(resolveImageViewerCloseAction(for: 49, entryMode: .closeButtonOnly))
        XCTAssertTrue(resolveImageViewerCloseAction(for: 53, entryMode: .closeButtonOnly))
    }

    func testResolveImageViewerNavigationIconAssets_UsesLocalArrowResourceNames() {
        let assets = resolveImageViewerNavigationIconAssets()
        XCTAssertEqual(assets.previous, "arrow-left-line")
        XCTAssertEqual(assets.next, "arrow-right-line")
    }

    func testResolveImageViewerBackdropStyle_KeepsOverlayMaterialSettingsStable() {
        let style = resolveImageViewerBackdropStyle()
        XCTAssertEqual(style.material, .underWindowBackground)
        XCTAssertEqual(style.blendingMode, .behindWindow)
    }

    func testResolveImageViewerBackdropStyle_UsesDarkMaskOpacity() {
        let style = resolveImageViewerBackdropStyle()
        XCTAssertEqual(style.tintAlpha, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(style.tintAlpha, 0.45)
        XCTAssertLessThanOrEqual(style.tintAlpha, 0.5)
    }

    func testResolveImageViewerBackdropStyle_EnablesSnapshotBlurOnDarkMask() {
        let style = resolveImageViewerBackdropStyle()
        XCTAssertEqual(style.snapshotBlurRadius, 100, accuracy: 0.001)
        XCTAssertGreaterThan(style.snapshotBlurRadius, 0)
    }

    func testResolveImageViewerBackdropStyle_UsesDownsampleScaleForSnapshotPerformance() {
        let style = resolveImageViewerBackdropStyle()
        XCTAssertEqual(style.snapshotDownsampleScale, 0.35, accuracy: 0.001)
        XCTAssertGreaterThan(style.snapshotDownsampleScale, 0)
        XCTAssertLessThan(style.snapshotDownsampleScale, 1)
    }

    func testResolveImageViewerBackdropStyle_UsesFastFadeTransition() {
        let style = resolveImageViewerBackdropStyle()
        XCTAssertEqual(style.transitionDuration, 0.16, accuracy: 0.001)
        XCTAssertGreaterThan(style.transitionDuration, 0)
        XCTAssertLessThanOrEqual(style.transitionDuration, 0.2)
    }

    func testResolveImageViewerBackdropCapturePolicies_WhenOverlayWindowExists_UsesBelowWindowThenOnScreen() {
        let policies = resolveImageViewerBackdropCapturePolicies(hasOverlayWindowNumber: true)
        XCTAssertEqual(
            policies,
            [.onScreenBelowOverlayWindow, .onScreenOnly]
        )
    }

    func testResolveImageViewerBackdropCapturePolicies_WhenOverlayWindowMissing_UsesOnScreenOnly() {
        let policies = resolveImageViewerBackdropCapturePolicies(hasOverlayWindowNumber: false)
        XCTAssertEqual(policies, [.onScreenOnly])
    }

    func testResolveImageViewerValidatedDownsampleScale_ClampsOutOfRangeValues() {
        XCTAssertEqual(resolveImageViewerValidatedDownsampleScale(0), 0.1, accuracy: 0.001)
        XCTAssertEqual(resolveImageViewerValidatedDownsampleScale(2), 1, accuracy: 0.001)
    }

    func testResolveImageViewerBlurRadiusForDownsample_ScalesRadiusWithDownsampleFactor() {
        let radius = resolveImageViewerBlurRadiusForDownsample(
            snapshotBlurRadius: 100,
            downsampleScale: 0.35
        )
        XCTAssertEqual(radius, 35, accuracy: 0.001)
    }

    func testResolveImageViewerShouldRefreshBackdropSnapshot_SkipsSameFrameWhenSnapshotExists() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertFalse(
            resolveImageViewerShouldRefreshBackdropSnapshot(
                previousFrame: frame,
                currentFrame: frame,
                hasSnapshotImage: true,
                forceRefresh: false
            )
        )
    }

    func testResolveImageViewerShouldRefreshBackdropSnapshot_RefreshesWhenFrameChangesOrImageMissing() {
        let previous = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let current = NSRect(x: 10, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(
            resolveImageViewerShouldRefreshBackdropSnapshot(
                previousFrame: previous,
                currentFrame: current,
                hasSnapshotImage: true,
                forceRefresh: false
            )
        )
        XCTAssertTrue(
            resolveImageViewerShouldRefreshBackdropSnapshot(
                previousFrame: previous,
                currentFrame: previous,
                hasSnapshotImage: false,
                forceRefresh: false
            )
        )
    }

    func testResolveImageViewerShouldRefreshBackdropSnapshot_ForceRefreshAlwaysTrue() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(
            resolveImageViewerShouldRefreshBackdropSnapshot(
                previousFrame: frame,
                currentFrame: frame,
                hasSnapshotImage: true,
                forceRefresh: true
            )
        )
    }

    func testResolveImageViewerOverlayWindowLevel_UsesFloatingLevelForStablePreview() {
        XCTAssertEqual(
            resolveImageViewerOverlayWindowLevel().rawValue,
            NSWindow.Level.floating.rawValue
        )
    }

    func testResolveImageViewerOverlayCollectionBehavior_UsesStableFullscreenAuxiliaryFlags() {
        let behavior = resolveImageViewerOverlayCollectionBehavior()
        XCTAssertTrue(behavior.contains(.moveToActiveSpace))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(behavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(behavior.contains(.stationary))
    }

    func testResolveImageViewerBackdropSnapshotScaling_UsesAxisIndependentScaleToGuaranteeCoverage() {
        XCTAssertEqual(
            resolveImageViewerBackdropSnapshotScaling(),
            .scaleAxesIndependently
        )
    }

    func testResolveImageViewerImageContainerBackgroundColor_RemovesMiddleOverlayLayer() {
        XCTAssertNil(resolveImageViewerImageContainerBackgroundColor())
    }

    func testResolveImageViewerImageCornerRadius_UsesEightPoints() {
        XCTAssertEqual(resolveImageViewerImageCornerRadius(), 8, accuracy: 0.001)
    }

    func testResolveImageViewerImageScaling_UsesProportionallyDownToPreventUpscale() {
        XCTAssertEqual(resolveImageViewerImageScaling(), .scaleProportionallyDown)
    }

    func testResolveImageViewerMaxContainerSize_UsesOverlayCapsWithoutMinimumImageSize() {
        let bounds = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxSize = resolveImageViewerMaxContainerSize(overlayBounds: bounds)
        XCTAssertEqual(maxSize.width, 984, accuracy: 0.001) // 1200 * 0.82
        XCTAssertEqual(maxSize.height, 624, accuracy: 0.001) // 800 * 0.78
    }

    func testResolveImageViewerDisplayedImageSize_DoesNotUpscaleSmallImage() {
        let size = resolveImageViewerDisplayedImageSize(
            imageSize: NSSize(width: 64, height: 48),
            maxContainerSize: NSSize(width: 900, height: 700)
        )
        XCTAssertEqual(size.width, 64, accuracy: 0.001)
        XCTAssertEqual(size.height, 48, accuracy: 0.001)
    }

    func testResolveImageViewerDisplayedImageSize_DownscalesLargeImageToContainer() {
        let size = resolveImageViewerDisplayedImageSize(
            imageSize: NSSize(width: 1600, height: 1200),
            maxContainerSize: NSSize(width: 400, height: 300)
        )
        XCTAssertEqual(size.width, 400, accuracy: 0.001)
        XCTAssertEqual(size.height, 300, accuracy: 0.001)
    }

    func testResolveImageViewerDisplayedImageSize_PreservesAspectRatioForTallImage() {
        let size = resolveImageViewerDisplayedImageSize(
            imageSize: NSSize(width: 600, height: 1200),
            maxContainerSize: NSSize(width: 400, height: 300)
        )
        XCTAssertEqual(size.width, 150, accuracy: 0.001)
        XCTAssertEqual(size.height, 300, accuracy: 0.001)
    }

    func testResolveImageViewerShouldCloseOnBackgroundClick_WhenHitViewIsNil_ReturnsTrue() {
        let imageView = NSView(frame: .zero)
        XCTAssertTrue(
            resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: nil,
                imageView: imageView,
                interactiveViews: []
            )
        )
    }

    func testResolveImageViewerShouldCloseOnBackgroundClick_WhenHitImageViewOrDescendant_ReturnsFalse() {
        let imageView = NSView(frame: .zero)
        let imageSubview = NSView(frame: .zero)
        imageView.addSubview(imageSubview)

        XCTAssertFalse(
            resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: imageView,
                imageView: imageView,
                interactiveViews: []
            )
        )
        XCTAssertFalse(
            resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: imageSubview,
                imageView: imageView,
                interactiveViews: []
            )
        )
    }

    func testResolveImageViewerShouldCloseOnBackgroundClick_WhenHitButtonArea_ReturnsFalse() {
        let imageView = NSView(frame: .zero)
        let actionRow = NSStackView()
        let button = NSButton(title: "Copy", target: nil, action: nil)
        actionRow.addSubview(button)

        XCTAssertFalse(
            resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: button,
                imageView: imageView,
                interactiveViews: [actionRow]
            )
        )
    }

    func testResolveImageViewerShouldCloseOnBackgroundClick_WhenHitBackgroundView_ReturnsTrue() {
        let imageView = NSView(frame: .zero)
        let backgroundView = NSView(frame: .zero)
        let actionRow = NSStackView()

        XCTAssertTrue(
            resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: backgroundView,
                imageView: imageView,
                interactiveViews: [actionRow]
            )
        )
    }

    func testResolveImageViewerNavigationButtonAlpha_WhenEnabled_UsesFullOpacity() {
        XCTAssertEqual(
            resolveImageViewerNavigationButtonAlpha(isEnabled: true),
            1.0,
            accuracy: 0.001
        )
    }

    func testResolveImageViewerNavigationButtonAlpha_WhenDisabled_UsesLowerOpacity() {
        XCTAssertEqual(
            resolveImageViewerNavigationButtonAlpha(isEnabled: false),
            0.28,
            accuracy: 0.001
        )
    }

    func testResolveImageViewerCGCaptureRect_ConvertsAppKitToCGCoordinates() {
        let appKitRect = NSRect(x: -1920, y: -30, width: 1920, height: 1080)
        let primaryHeight: CGFloat = 1050
        let cgRect = resolveImageViewerCGCaptureRect(
            appKitRect: appKitRect,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(cgRect.origin.x, -1920, accuracy: 0.01)
        XCTAssertEqual(cgRect.origin.y, 0, accuracy: 0.01)
        XCTAssertEqual(cgRect.width, 1920, accuracy: 0.01)
        XCTAssertEqual(cgRect.height, 1080, accuracy: 0.01)
    }

    func testResolveImageViewerCGCaptureRect_PrimaryScreenIsIdentity() {
        let appKitRect = NSRect(x: 0, y: 0, width: 1680, height: 1050)
        let primaryHeight: CGFloat = 1050
        let cgRect = resolveImageViewerCGCaptureRect(
            appKitRect: appKitRect,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(cgRect.origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(cgRect.origin.y, 0, accuracy: 0.01)
        XCTAssertEqual(cgRect.width, 1680, accuracy: 0.01)
        XCTAssertEqual(cgRect.height, 1050, accuracy: 0.01)
    }

    func testResolveImageViewerBackdropRenderMode_UsesSnapshotWhenReduceTransparencyEnabled() {
        XCTAssertEqual(
            resolveImageViewerBackdropRenderMode(reduceTransparencyEnabled: true),
            .capturedBlurSnapshot
        )
    }

    func testResolveImageViewerBackdropRenderMode_UsesSystemMaterialWhenTransparencyAllowed() {
        XCTAssertEqual(
            resolveImageViewerBackdropRenderMode(reduceTransparencyEnabled: false),
            .systemMaterial
        )
    }

    func testResolveImageViewerSwipeNavigation_LeftSwipeMovesNext() {
        XCTAssertEqual(resolveImageViewerSwipeNavigation(deltaX: 1), .next)
    }

    func testResolveImageViewerSwipeNavigation_RightSwipeMovesPrevious() {
        XCTAssertEqual(resolveImageViewerSwipeNavigation(deltaX: -1), .previous)
    }

    func testResolveImageViewerOverlayFrame_PrefersLibraryWindowScreen() {
        let screens = [
            NSRect(x: 0, y: 0, width: 1920, height: 1080),
            NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        ]
        let anchorWindowFrame = NSRect(x: 2100, y: 200, width: 900, height: 700)
        let resolved = resolveImageViewerOverlayFrame(
            anchorWindowFrame: anchorWindowFrame,
            mouseLocation: NSPoint(x: 100, y: 100),
            screenFrames: screens,
            mainScreenFrame: screens[0]
        )
        XCTAssertEqual(resolved, screens[1])
    }

    func testResolveImageViewerOverlayFrame_FallsBackToMouseScreenWhenAnchorMissing() {
        let screens = [
            NSRect(x: 0, y: 0, width: 1920, height: 1080),
            NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        ]
        let resolved = resolveImageViewerOverlayFrame(
            anchorWindowFrame: nil,
            mouseLocation: NSPoint(x: 2500, y: 500),
            screenFrames: screens,
            mainScreenFrame: screens[0]
        )
        XCTAssertEqual(resolved, screens[1])
    }

    func testResolveImageViewerOverlayFrame_FallsBackToMainScreenWhenMouseOutsideAllScreens() {
        let screens = [NSRect(x: 0, y: 0, width: 1728, height: 1117)]
        let main = NSRect(x: 100, y: 50, width: 1512, height: 982)
        let resolved = resolveImageViewerOverlayFrame(
            anchorWindowFrame: nil,
            mouseLocation: NSPoint(x: -9999, y: -9999),
            screenFrames: screens,
            mainScreenFrame: main
        )
        XCTAssertEqual(resolved, main)
    }

    func testResolveImageViewerOverlayFrame_UsesConservativeDefaultWhenNoScreens() {
        let resolved = resolveImageViewerOverlayFrame(
            anchorWindowFrame: nil,
            mouseLocation: NSPoint(x: 0, y: 0),
            screenFrames: [],
            mainScreenFrame: nil
        )
        XCTAssertEqual(resolved, NSRect(x: 0, y: 0, width: 1440, height: 900))
    }

    func testResolveImageViewerIndexAfterDelete_PrefersNextWhenAvailable() {
        let resolved = resolveImageViewerIndexAfterDelete(currentIndex: 1, itemCountAfterDeletion: 3)
        XCTAssertEqual(resolved, 1)
    }

    func testResolveImageViewerIndexAfterDelete_FallsBackToPreviousAtEnd() {
        let resolved = resolveImageViewerIndexAfterDelete(currentIndex: 2, itemCountAfterDeletion: 2)
        XCTAssertEqual(resolved, 1)
    }

    func testResolveImageViewerIndexAfterDelete_ReturnsNilWhenNoItemsRemain() {
        XCTAssertNil(resolveImageViewerIndexAfterDelete(currentIndex: 0, itemCountAfterDeletion: 0))
    }

    func testResolveDeleteRequiresConfirmation_WhenSingleItem_ReturnsFalse() {
        XCTAssertFalse(resolveDeleteRequiresConfirmation(itemCount: 1))
    }

    func testResolveDeleteRequiresConfirmation_WhenMultipleItems_ReturnsTrue() {
        XCTAssertTrue(resolveDeleteRequiresConfirmation(itemCount: 2))
    }

    func testResolveLibraryActionState_WhenNoSelection_HidesAndDisablesAllActions() {
        let state = resolveLibraryActionState(selectionCount: 0, allSelectedKept: false)
        XCTAssertFalse(state.showsSelectionActions)
        XCTAssertFalse(state.copyEnabled)
        XCTAssertFalse(state.openEnabled)
        XCTAssertFalse(state.keepEnabled)
        XCTAssertFalse(state.deleteEnabled)
        XCTAssertEqual(state.keepTitle, "Keep")
    }

    func testResolveLibraryActionState_WhenSingleSelection_EnablesAllActions() {
        let state = resolveLibraryActionState(selectionCount: 1, allSelectedKept: false)
        XCTAssertTrue(state.showsSelectionActions)
        XCTAssertTrue(state.copyEnabled)
        XCTAssertTrue(state.openEnabled)
        XCTAssertTrue(state.keepEnabled)
        XCTAssertTrue(state.deleteEnabled)
        XCTAssertEqual(state.keepTitle, "Keep")
    }

    func testResolveLibraryActionState_WhenMultipleSelection_DisablesOpen() {
        let state = resolveLibraryActionState(selectionCount: 3, allSelectedKept: true)
        XCTAssertTrue(state.showsSelectionActions)
        XCTAssertTrue(state.copyEnabled)
        XCTAssertFalse(state.openEnabled)
        XCTAssertTrue(state.keepEnabled)
        XCTAssertTrue(state.deleteEnabled)
        XCTAssertEqual(state.keepTitle, "Unkeep")
    }

    func testResolveLibraryCopyHUDKey_WhenSingleImage_UsesSingleKey() {
        XCTAssertEqual(resolveLibraryCopyHUDKey(copiedCount: 1), "hud.image_copied")
    }

    func testResolveLibraryCopyHUDKey_WhenMultipleImages_UsesPluralKey() {
        XCTAssertEqual(resolveLibraryCopyHUDKey(copiedCount: 3), "hud.images_copied")
    }

    func testClipboardServiceCopyImages_WhenEmpty_ThrowsWriteFailed() {
        XCTAssertThrowsError(try ClipboardService.shared.copy(images: [], prompt: "")) { error in
            guard case ClipboardError.writeFailed = error else {
                XCTFail("Expected ClipboardError.writeFailed, got \(error)")
                return
            }
        }
    }

    func testClipboardServiceCopyImagesWithFileURLs_WritesFileURLAndBitmapTypes() throws {
        let fileManager = FileManager.default
        let temporaryFolderURL = fileManager.temporaryDirectory.appendingPathComponent(
            "vibecap-clipboard-types-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryFolderURL) }

        let fileURL = try writeImage(named: "clipboard-types.png", in: temporaryFolderURL)
        guard let image = NSImage(contentsOf: fileURL) else {
            XCTFail("Expected NSImage from test fixture.")
            return
        }

        try ClipboardService.shared.copy(images: [image], fileURLs: [fileURL], prompt: "")

        guard let item = NSPasteboard.general.pasteboardItems?.first else {
            XCTFail("Expected at least one pasteboard item.")
            return
        }

        XCTAssertTrue(item.types.contains(.fileURL))
        XCTAssertTrue(item.types.contains(.png) || item.types.contains(.tiff))
    }

    func testClipboardServiceCopyImagesWithFileURLs_WritesOneItemPerFile() throws {
        let fileManager = FileManager.default
        let temporaryFolderURL = fileManager.temporaryDirectory.appendingPathComponent(
            "vibecap-clipboard-count-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryFolderURL) }

        let fileURL0 = try writeImage(named: "clipboard-count-0.png", in: temporaryFolderURL)
        let fileURL1 = try writeImage(named: "clipboard-count-1.png", in: temporaryFolderURL)
        guard
            let image0 = NSImage(contentsOf: fileURL0),
            let image1 = NSImage(contentsOf: fileURL1)
        else {
            XCTFail("Expected NSImage fixtures for multi-copy test.")
            return
        }

        try ClipboardService.shared.copy(
            images: [image0, image1],
            fileURLs: [fileURL0, fileURL1],
            prompt: ""
        )

        XCTAssertEqual(NSPasteboard.general.pasteboardItems?.count, 2)
    }

    func testResolveOverlayMouseUpAction_WhenNoSelection_SchedulesCancel() {
        XCTAssertEqual(
            resolveOverlayMouseUpAction(clickCount: 1, selectionRectGlobal: nil),
            .scheduleCancel
        )
    }

    func testResolveOverlayMouseUpAction_WhenTinySelection_CancelsImmediately() {
        XCTAssertEqual(
            resolveOverlayMouseUpAction(
                clickCount: 1,
                selectionRectGlobal: CGRect(x: 10, y: 10, width: 2, height: 2)
            ),
            .cancelNow
        )
    }

    func testResolveOverlayMouseUpAction_WhenValidSelection_CapturesSelection() {
        XCTAssertEqual(
            resolveOverlayMouseUpAction(
                clickCount: 1,
                selectionRectGlobal: CGRect(x: 10, y: 10, width: 50, height: 40)
            ),
            .captureSelection(CGRect(x: 10, y: 10, width: 50, height: 40))
        )
    }

    func testResolveOverlayMouseUpAction_WhenDoubleClick_CapturesFullScreen() {
        XCTAssertEqual(
            resolveOverlayMouseUpAction(
                clickCount: 2,
                selectionRectGlobal: nil
            ),
            .captureFullScreen
        )
    }

    func testShouldShowOverlayInteractionHint_AlwaysReturnsTrue() {
        XCTAssertTrue(shouldShowOverlayInteractionHint())
    }

    func testResolveLibraryCopyStrategy_WhenSingleSelection_UsesDirectClipboard() {
        XCTAssertEqual(
            resolveLibraryCopyStrategy(selectionCount: 1, hasAccessibilityPermission: false),
            .directClipboard
        )
    }

    func testResolveLibraryCopyStrategy_WhenMultiSelectionAndHasAccessibility_UsesArmedAutoPaste() {
        XCTAssertEqual(
            resolveLibraryCopyStrategy(selectionCount: 3, hasAccessibilityPermission: true),
            .armedAutoPaste
        )
    }

    func testResolveLibraryCopyStrategy_WhenMultiSelectionWithoutAccessibility_RequiresPermission() {
        XCTAssertEqual(
            resolveLibraryCopyStrategy(selectionCount: 3, hasAccessibilityPermission: false),
            .requiresAccessibilityPermission
        )
    }

    func testResolveLibraryMarqueeSelection_WhenCommandNotActive_ReplacesSelection() {
        let initial: Set<IndexPath> = [IndexPath(item: 1, section: 0)]
        let hit: Set<IndexPath> = [IndexPath(item: 2, section: 0), IndexPath(item: 3, section: 0)]

        let result = resolveLibraryMarqueeSelection(
            initialSelection: initial,
            hitSelection: hit,
            isCommandModifierActive: false
        )

        XCTAssertEqual(result, hit)
    }

    func testResolveLibraryMarqueeSelection_WhenCommandActive_TogglesSelection() {
        let initial: Set<IndexPath> = [IndexPath(item: 1, section: 0), IndexPath(item: 2, section: 0)]
        let hit: Set<IndexPath> = [IndexPath(item: 2, section: 0), IndexPath(item: 3, section: 0)]

        let result = resolveLibraryMarqueeSelection(
            initialSelection: initial,
            hitSelection: hit,
            isCommandModifierActive: true
        )

        XCTAssertEqual(result, Set([IndexPath(item: 1, section: 0), IndexPath(item: 3, section: 0)]))
    }

    func testResolveLibraryMarqueeSelection_WhenCommandActiveAndNoOverlap_AddsSelection() {
        let initial: Set<IndexPath> = [IndexPath(item: 1, section: 0)]
        let hit: Set<IndexPath> = [IndexPath(item: 3, section: 0)]

        let result = resolveLibraryMarqueeSelection(
            initialSelection: initial,
            hitSelection: hit,
            isCommandModifierActive: true
        )

        XCTAssertEqual(result, Set([IndexPath(item: 1, section: 0), IndexPath(item: 3, section: 0)]))
    }

    func testResolveLibraryMarqueeRect_WhenDraggingForward_ComputesPositiveRect() {
        let rect = resolveLibraryMarqueeRect(
            start: NSPoint(x: 10, y: 20),
            current: NSPoint(x: 60, y: 90)
        )

        XCTAssertEqual(rect.origin.x, 10, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 20, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 50, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 70, accuracy: 0.001)
    }

    func testResolveLibraryMarqueeRect_WhenDraggingBackward_NormalizesRect() {
        let rect = resolveLibraryMarqueeRect(
            start: NSPoint(x: 80, y: 70),
            current: NSPoint(x: 30, y: 20)
        )

        XCTAssertEqual(rect.origin.x, 30, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 20, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 50, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 50, accuracy: 0.001)
    }

    func testResolveLibraryMarqueeStyle_UsesSubtleFillAndStrokeOpacity() {
        let style = resolveLibraryMarqueeStyle()
        XCTAssertEqual(style.fillColor.alphaComponent, 0.08, accuracy: 0.001)
        XCTAssertEqual(style.strokeColor.alphaComponent, 0.28, accuracy: 0.001)
    }

    func testResolveLibraryMarqueeStyle_StrokeIsMoreVisibleThanFill() {
        let style = resolveLibraryMarqueeStyle()
        XCTAssertGreaterThan(style.strokeColor.alphaComponent, style.fillColor.alphaComponent)
    }

    private func findCollectionView(in view: NSView) -> NSCollectionView? {
        if let collectionView = view as? NSCollectionView {
            return collectionView
        }
        for subview in view.subviews {
            if let collectionView = findCollectionView(in: subview) {
                return collectionView
            }
        }
        return nil
    }

    private func findButton(titled title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let match = findButton(titled: title, in: subview) {
                return match
            }
        }
        return nil
    }

    private func findButton(identifier: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.identifier?.rawValue == identifier {
            return button
        }
        for subview in view.subviews {
            if let match = findButton(identifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }

    private func findSegmentedControl(identifier: String, in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl, control.identifier?.rawValue == identifier {
            return control
        }
        for subview in view.subviews {
            if let match = findSegmentedControl(identifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }

    private func withLibraryWindowHavingItems(
        perform: (LibraryWindowController, NSCollectionView) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let temporaryFolderURL = fileManager.temporaryDirectory.appendingPathComponent("vibecap-library-window-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
        let originalBookmark = SettingsStore.shared.saveFolderBookmark
        defer {
            SettingsStore.shared.saveFolderBookmark = originalBookmark
            try? fileManager.removeItem(at: temporaryFolderURL)
        }

        _ = try writeImage(named: "multi-0.png", in: temporaryFolderURL)
        _ = try writeImage(named: "multi-1.png", in: temporaryFolderURL)
        let bookmark = try temporaryFolderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        SettingsStore.shared.saveFolderBookmark = bookmark

        let sut = LibraryWindowController()
        guard let rootView = sut.window?.contentViewController?.view else {
            XCTFail("Expected library content view to be available.")
            return
        }
        sut.reload()

        guard let collectionView = findCollectionView(in: rootView) else {
            XCTFail("Expected NSCollectionView in library window.")
            return
        }
        try perform(sut, collectionView)
    }

    private func writeImage(named name: String, in folderURL: URL) throws -> URL {
        let url = folderURL.appendingPathComponent(name)
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        guard let data = image.pngData() else {
            XCTFail("Failed to encode image data in test fixture.")
            throw LibraryServiceError.failedToLoadImage
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

