import XCTest
@testable import VibeCap

final class OnboardingStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: OnboardingStore!
    private var domain: String!

    override func setUp() {
        super.setUp()
        domain = "OnboardingStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        sut = OnboardingStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: domain)
        defaults = nil
        sut = nil
        domain = nil
        super.tearDown()
    }

    func testDefaultStepIsWelcome() {
        XCTAssertEqual(sut.step, .welcome)
        XCTAssertFalse(sut.isFlowCompleted)
    }

    func testSettingStepPersists() {
        sut.step = .preferences
        XCTAssertEqual(sut.step, .preferences)
    }

    func testMarkFlowCompletedSetsFlowCompletedAndStepDone() {
        sut.step = .accessibility
        sut.markFlowCompleted(now: Date(timeIntervalSince1970: 1))

        XCTAssertTrue(sut.isFlowCompleted)
        XCTAssertEqual(sut.step, .done)
    }

    func testMarkFlowCompletedClearsResumeAfterRestartFlag() {
        sut.shouldResumeAfterRestart = true
        sut.markFlowCompleted(now: Date(timeIntervalSince1970: 1))
        XCTAssertFalse(sut.shouldResumeAfterRestart)
    }
}

