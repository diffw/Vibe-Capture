import Foundation

/// Pure helper to decide where onboarding should start given current permission state.
/// Keeps behavior consistent between app launch, restart, and in-flow polling.
enum OnboardingAutoAdvance {
    static func normalizeStartStep(
        stored: OnboardingStep,
        screenRecordingGranted: Bool,
        accessibilityGranted: Bool
    ) -> OnboardingStep {
        // If already completed, do not show onboarding.
        if stored == .done { return .done }

        // Do not auto-skip permission steps; show granted state + let user tap Continue.
        _ = screenRecordingGranted
        _ = accessibilityGranted
        return stored
    }
}

