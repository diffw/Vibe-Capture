import AppKit
import CoreGraphics

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required to capture your screen."
        case .captureFailed:
            return "Unable to capture the selected area."
        }
    }
}

final class ScreenCaptureService {
    func ensurePermissionOrRequest() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        // Shows the system prompt. User may need to restart the app after granting.
        _ = CGRequestScreenCaptureAccess()
        return CGPreflightScreenCaptureAccess()
    }

    func capture(rect: CGRect, belowWindowID: CGWindowID?) throws -> NSImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }

        let cgRect = Self.cocoaToQuartzGlobalRect(rect)
        let option: CGWindowListOption = (belowWindowID != nil) ? .optionOnScreenBelowWindow : .optionOnScreenOnly
        let windowID: CGWindowID = belowWindowID ?? kCGNullWindowID

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            option,
            windowID,
            [.bestResolution]
        ) else {
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
