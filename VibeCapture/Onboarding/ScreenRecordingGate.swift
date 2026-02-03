import AppKit
import CoreGraphics

enum ScreenRecordingGate {
    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Returns true if permission is granted; otherwise shows a modal-like window and returns false.
    @discardableResult
    static func ensureOrShowModal() -> Bool {
        guard hasPermission() else {
            ScreenRecordingGateWindowController.shared.show()
            return false
        }
        return true
    }
}

