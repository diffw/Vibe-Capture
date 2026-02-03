import XCTest
@testable import VibeCap

final class OnboardingAutoAdvanceTests: XCTestCase {
    func testDoneRemainsDone() {
        let step = OnboardingAutoAdvance.normalizeStartStep(
            stored: .done,
            screenRecordingGranted: true,
            accessibilityGranted: true
        )
        XCTAssertEqual(step, .done)
    }

    func testScreenRecordingStepSkipsToAccessibilityWhenAlreadyGranted() {
        let step = OnboardingAutoAdvance.normalizeStartStep(
            stored: .screenRecording,
            screenRecordingGranted: true,
            accessibilityGranted: false
        )
        XCTAssertEqual(step, .screenRecording)
    }

    func testAccessibilityStepSkipsToPreferencesWhenAlreadyGranted() {
        let step = OnboardingAutoAdvance.normalizeStartStep(
            stored: .accessibility,
            screenRecordingGranted: true,
            accessibilityGranted: true
        )
        XCTAssertEqual(step, .accessibility)
    }

    func testWelcomeDoesNotAutoSkip() {
        let step = OnboardingAutoAdvance.normalizeStartStep(
            stored: .welcome,
            screenRecordingGranted: true,
            accessibilityGranted: true
        )
        XCTAssertEqual(step, .welcome)
    }
}

