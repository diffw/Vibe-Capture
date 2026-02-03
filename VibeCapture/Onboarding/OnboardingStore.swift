import Foundation

final class OnboardingStore {
    static let shared = OnboardingStore()

    private let defaults: UserDefaults

    enum Key {
        static let step = "onboarding.step"
        // Legacy key (previously used to mean "completed"). Kept for migration.
        static let legacyCompleted = "onboarding.completed"
        // New key: only set when the user finishes the full onboarding flow.
        static let flowCompleted = "onboarding.flowCompleted"
        static let flowCompletedAt = "onboarding.flowCompletedAt"
        static let dismissedAt = "onboarding.dismissedAt"
        static let startedAt = "onboarding.startedAt"
        static let resumeAfterRestart = "onboarding.resumeAfterRestart"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateIfNeeded()
    }

    /// True only when the user finishes all onboarding steps (01–05).
    var isFlowCompleted: Bool {
        defaults.bool(forKey: Key.flowCompleted)
    }

    var step: OnboardingStep {
        get {
            guard
                let raw = defaults.string(forKey: Key.step),
                let step = OnboardingStep(rawValue: raw)
            else {
                return .welcome
            }
            return step
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.step)
        }
    }

    var startedAt: Date? {
        defaults.object(forKey: Key.startedAt) as? Date
    }

    var dismissedAt: Date? {
        defaults.object(forKey: Key.dismissedAt) as? Date
    }

    /// When true, onboarding should reopen after the next app launch
    /// (e.g. the system requested "Quit & Reopen" after granting Screen Recording).
    var shouldResumeAfterRestart: Bool {
        get { defaults.bool(forKey: Key.resumeAfterRestart) }
        set {
            defaults.set(newValue, forKey: Key.resumeAfterRestart)
            // Best-effort flush: system-driven "Quit & Reopen" can terminate quickly.
            defaults.synchronize()
        }
    }

    func markStartedIfNeeded(now: Date = Date()) {
        if defaults.object(forKey: Key.startedAt) == nil {
            defaults.set(now, forKey: Key.startedAt)
        }
    }

    /// Called when user dismisses onboarding (e.g. closes the window),
    /// but has NOT completed the full flow.
    func markDismissed(now: Date = Date()) {
        defaults.set(now, forKey: Key.dismissedAt)
    }

    /// Called only when user finishes the full onboarding flow.
    func markFlowCompleted(now: Date = Date()) {
        defaults.set(true, forKey: Key.flowCompleted)
        defaults.set(now, forKey: Key.flowCompletedAt)
        defaults.set(false, forKey: Key.resumeAfterRestart)
        defaults.set(OnboardingStep.done.rawValue, forKey: Key.step)
    }

    func resetForDebug() {
        defaults.removeObject(forKey: Key.step)
        defaults.removeObject(forKey: Key.legacyCompleted)
        defaults.removeObject(forKey: Key.flowCompleted)
        defaults.removeObject(forKey: Key.flowCompletedAt)
        defaults.removeObject(forKey: Key.dismissedAt)
        defaults.removeObject(forKey: Key.startedAt)
        defaults.removeObject(forKey: Key.resumeAfterRestart)
    }

    private func migrateIfNeeded() {
        // Legacy behavior stored `onboarding.completed` to mean "closed the onboarding window".
        // That caused two issues:
        // - System-driven "Quit & Reopen" could mark onboarding as completed incorrectly.
        // - It prevented resuming onboarding later.
        //
        // Migration strategy:
        // - If the new key doesn't exist, we treat legacy `onboarding.completed` as "dismissed",
        //   NOT as "flow completed".
        if defaults.object(forKey: Key.flowCompleted) == nil {
            if defaults.bool(forKey: Key.legacyCompleted) {
                // Keep `dismissedAt` (already present in legacy), but ensure flowCompleted is false.
                defaults.set(false, forKey: Key.flowCompleted)
            }
        }
    }
}

