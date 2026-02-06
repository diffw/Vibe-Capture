import AppKit
import CoreGraphics

enum ScreenRecordingGate {
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Returns true if permission is granted; otherwise shows a modal-like window and returns false.
    @discardableResult
    static func ensureOrShowModal() -> Bool {
        let ok = hasPermission()
        AppLog.log(.info, "permissions", "ScreenRecordingGate.ensureOrShowModal preflight=\(ok)")
        guard !ok else {
            AppLog.log(.info, "permissions", "ScreenRecordingGate.ensureOrShowModal permission granted, returning true")
            return true
        }

        // Always show custom gate first; user clicks Allow to trigger system settings flow.
        AppLog.log(.warn, "permissions", "ScreenRecordingGate.ensureOrShowModal missing permission -> calling ScreenRecordingGateWindowController.shared.show()")
        ScreenRecordingGateWindowController.shared.show()
        AppLog.log(.info, "permissions", "ScreenRecordingGate.ensureOrShowModal show() called, returning false")
        return false
    }
}

