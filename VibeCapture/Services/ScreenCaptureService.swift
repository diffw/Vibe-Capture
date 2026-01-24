import AppKit
import CoreGraphics

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return L("permission.screen_recording.error")
        case .captureFailed:
            return L("error.capture_failed")
        }
    }
}

final class ScreenCaptureService {
    func ensurePermissionOrRequest() -> Bool {
        let span = AppLog.span("capture", "ensurePermissionOrRequest")
        defer { span.end(.info) }

        if CGPreflightScreenCaptureAccess() {
            AppLog.log(.debug, "capture", "CGPreflightScreenCaptureAccess = true")
            return true
        }
        // Shows the system prompt. User may need to restart the app after granting.
        AppLog.log(.warn, "capture", "CGPreflightScreenCaptureAccess = false; requesting access")
        _ = CGRequestScreenCaptureAccess()
        let ok = CGPreflightScreenCaptureAccess()
        AppLog.log(.info, "capture", "CGPreflight after request = \(ok)")
        return ok
    }

    func capture(rect: CGRect, belowWindowID: CGWindowID?) throws -> NSImage {
        let span = AppLog.span("capture", "CGWindowListCreateImage", meta: [
            "w": Int(rect.width),
            "h": Int(rect.height),
        ])
        defer { span.end(.info) }

        guard CGPreflightScreenCaptureAccess() else {
            AppLog.log(.error, "capture", "capture denied: no screen recording permission")
            throw ScreenCaptureError.permissionDenied
        }

        let cgRect = Self.cocoaToQuartzGlobalRect(rect)
        let option: CGWindowListOption = (belowWindowID != nil) ? .optionOnScreenBelowWindow : .optionOnScreenOnly
        let windowID: CGWindowID = belowWindowID ?? kCGNullWindowID

        AppLog.log(.debug, "capture", "CGWindowListCreateImage rect=\(cgRect) option=\(option) windowID=\(windowID)")
        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            option,
            windowID,
            [.bestResolution]
        ) else {
            AppLog.log(.error, "capture", "CGWindowListCreateImage returned nil")
            throw ScreenCaptureError.captureFailed
        }

        // Use the original rect size (in points), not the CGImage pixel size.
        // On Retina displays, cgImage.width/height are 2x the point size.
        return NSImage(cgImage: cgImage, size: rect.size)
    }

    /// Converts Cocoa's global screen coordinates (origin bottom-left) to Quartz display coordinates
    /// (origin top-left of the primary display).
    private static func cocoaToQuartzGlobalRect(_ rect: CGRect) -> CGRect {
        let primary = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: 0, y: 0)) }) ?? NSScreen.screens.first
        let primaryHeight = primary?.frame.height ?? 0
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }
}
