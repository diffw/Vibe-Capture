import AppKit
import ApplicationServices
import CoreGraphics

enum PermissionsUI {
    private static func markShouldResumeOnboardingAfterRestart(minimumStep: OnboardingStep) {
        let store = OnboardingStore.shared
        guard !store.isFlowCompleted else { return }

        // Ensure onboarding can be resumed even if it was never auto-shown (e.g. user previously dismissed it).
        store.markStartedIfNeeded()

        // Never move backwards in the flow; only advance the stored step as needed.
        if store.step.index < minimumStep.index {
            store.step = minimumStep
        }

        // The system may request "Quit & Reopen" after toggling permissions.
        store.shouldResumeAfterRestart = true
        store.writeResumeMarker(minimumStep: minimumStep)
        AppLog.log(.info, "permissions", "Marked resumeAfterRestart minimumStep=\(minimumStep.rawValue) \(store.debugSnapshot())")
    }

    static func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = L("permission.screen_recording.title")
        alert.informativeText = L("permission.screen_recording.message")
        alert.addButton(withTitle: L("button.open_system_settings"))
        alert.addButton(withTitle: L("button.cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    static func openScreenRecordingSettings() {
        // Only mark resume when permission is currently missing (this is the case that triggers
        // the system "Quit & Reopen" flow users must complete).
        let preflight = CGPreflightScreenCaptureAccess()
        AppLog.log(.info, "permissions", "openScreenRecordingSettings preflight=\(preflight)")
        if !preflight {
            markShouldResumeOnboardingAfterRestart(minimumStep: .screenRecording)
        }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
        activateSystemSettings()
    }

    static func openAccessibilitySettings() {
        // Only mark resume when permission is currently missing.
        let trusted = AXIsProcessTrusted()
        AppLog.log(.info, "permissions", "openAccessibilitySettings trusted=\(trusted)")
        if !trusted {
            markShouldResumeOnboardingAfterRestart(minimumStep: .accessibility)
        }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
        activateSystemSettings()
    }

    private static func activateSystemSettings() {
        // Best-effort: bring System Settings to front so users can complete the permission flow.
        let bundleID = "com.apple.systempreferences"
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            _ = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
    }
}



