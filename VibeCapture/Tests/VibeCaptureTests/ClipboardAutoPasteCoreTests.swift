import XCTest
@testable import VibeCap

final class ClipboardAutoPasteCoreTests: XCTestCase {
    func testArmEmitsExpectedEffects() {
        var core = ClipboardAutoPasteCore()
        core.config = .init(delayBetweenPastes: 0.25, armTimeoutSeconds: 10, restoreClipboardAfter: true)
        core.prepare(text: "hello", imageCount: 1)

        let effects = core.arm()

        XCTAssertEqual(core.state, .armed)
        XCTAssertEqual(effects, [
            .captureClipboard,
            .writeTextOnly("hello"),
            .startMonitoring,
            .startTimeout(10),
        ])
    }

    func testUserPasteDetectedWithOneImageWritesImageAndSchedulesRestore() {
        var core = ClipboardAutoPasteCore()
        core.config = .init(delayBetweenPastes: 0.2, armTimeoutSeconds: 10, restoreClipboardAfter: true, userPasteSettlingDelay: 0.25)
        core.prepare(text: "t", imageCount: 1)
        _ = core.arm()

        let effects = core.userPasteDetected()

        XCTAssertEqual(core.state, .autoPasting(nextIndex: 0))
        XCTAssertEqual(effects, [
            .stopMonitoring,
            .cancelTimeout,
            .scheduleNextPaste(after: 0.25),
        ])

        let tick = core.autoPasteTick()
        XCTAssertEqual(core.state, .idle)
        XCTAssertEqual(tick, [
            .writeImageOnly(index: 0),
            .simulatePaste,
            .scheduleRestoreClipboard(after: 0.2),
        ])
    }

    func testUserPasteDetectedWithTwoImagesSchedulesNextPasteThenRestore() {
        var core = ClipboardAutoPasteCore()
        core.config = .init(delayBetweenPastes: 0.3, armTimeoutSeconds: 10, restoreClipboardAfter: true, userPasteSettlingDelay: 0.25)
        core.prepare(text: "t", imageCount: 2)
        _ = core.arm()

        let first = core.userPasteDetected()

        XCTAssertEqual(core.state, .autoPasting(nextIndex: 0))
        XCTAssertEqual(first, [
            .stopMonitoring,
            .cancelTimeout,
            .scheduleNextPaste(after: 0.25),
        ])

        let second = core.autoPasteTick()

        XCTAssertEqual(core.state, .autoPasting(nextIndex: 1))
        XCTAssertEqual(second, [
            .writeImageOnly(index: 0),
            .simulatePaste,
            .scheduleNextPaste(after: 0.3),
        ])

        let third = core.autoPasteTick()
        XCTAssertEqual(core.state, .idle)
        XCTAssertEqual(third, [
            .writeImageOnly(index: 1),
            .simulatePaste,
            .scheduleRestoreClipboard(after: 0.3),
        ])
    }

    func testTimeoutFiredDisarmsAndRestoresClipboardWhenEnabled() {
        var core = ClipboardAutoPasteCore()
        core.config = .init(delayBetweenPastes: 0.25, armTimeoutSeconds: 1, restoreClipboardAfter: true)
        core.prepare(text: "t", imageCount: 1)
        _ = core.arm()

        let effects = core.timeoutFired()

        XCTAssertEqual(core.state, .idle)
        XCTAssertEqual(effects, [
            .stopMonitoring,
            .cancelTimeout,
            .restoreClipboard,
        ])
    }
}

