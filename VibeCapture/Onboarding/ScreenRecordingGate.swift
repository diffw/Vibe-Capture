import AppKit
import CoreGraphics

enum ScreenRecordingGate {
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system prompt if permission is missing. Returns true if granted afterward.
    @discardableResult
    static func requestPermissionIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            AppLog.log(.info, "permissions", "ScreenRecordingGate.requestPermissionIfNeeded preflight=true (skip request)")
            return true
        }
        let granted = CGRequestScreenCaptureAccess()
        AppLog.log(.info, "permissions", "ScreenRecordingGate.requestPermissionIfNeeded requested result=\(granted)")
        return granted
    }

    /// Returns true if permission is granted; otherwise shows a modal-like window and returns false.
    @discardableResult
    static func ensureOrShowModal() -> Bool {
        let ok = hasPermission()
        AppLog.log(.info, "permissions", "ScreenRecordingGate.ensureOrShowModal preflight=\(ok)")
        guard !ok else { return true }

        // Show the custom gate first; the system dialog / System Settings are triggered from the gate's Allow button.
        AppLog.log(.warn, "permissions", "ScreenRecordingGate.ensureOrShowModal missing permission -> show gate (no prompt yet)")
        ScreenRecordingGateWindowController.shared.show()
        return false
    }
}

