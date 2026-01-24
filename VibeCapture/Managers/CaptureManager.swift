import AppKit

final class CaptureManager {
    private let overlay = ScreenshotOverlayController()
    private let captureService = ScreenCaptureService()

    private var modal: CaptureModalWindowController?

    func startCapture() {
        let span = AppLog.span("capture", "startCapture")
        defer { span.end(.info) }

        guard captureService.ensurePermissionOrRequest() else {
            AppLog.log(.warn, "capture", "Screen recording permission missing; showing permission alert")
            PermissionsUI.showScreenRecordingPermissionAlert()
            return
        }
        
        // Record the current frontmost app before showing overlay
        AppDetectionService.shared.recordCurrentAppAsPrevious()
        AppLog.log(.info, "capture", "Starting overlay selection")

        overlay.start { [weak self] rect, belowWindowID in
            guard let self, let rect else { return }
            self.captureSelectedRect(rect, belowWindowID: belowWindowID)
        }
    }

    private func captureSelectedRect(_ rect: CGRect, belowWindowID: CGWindowID?) {
        let span = AppLog.span("capture", "captureSelectedRect", meta: [
            "w": Int(rect.width),
            "h": Int(rect.height),
            "x": Int(rect.origin.x),
            "y": Int(rect.origin.y),
        ])

        // IMPORTANT: Capture can be slow on some systems. Never block the main thread
        // (otherwise the UI feels "locked" and the overlay may appear frozen).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let image = try self.captureService.capture(rect: rect, belowWindowID: belowWindowID)
                span.end(.info, extra: ["result": "ok"])
                DispatchQueue.main.async {
                    self.presentModal(with: image)
                }
            } catch {
                span.end(.error, extra: ["result": "error", "error": String(describing: error)])
                DispatchQueue.main.async {
                    HUDService.shared.show(message: error.localizedDescription, style: .error)
                }
            }
        }
    }

    private func presentModal(with image: NSImage) {
        let span = AppLog.span("capture", "presentModal", meta: ["img_w": Int(image.size.width), "img_h": Int(image.size.height)])
        defer { span.end(.info) }

        // Close any existing modal before creating a new one
        if let existingModal = modal {
            existingModal.close()
        }
        modal = nil
        
        let session = CaptureSession(image: image, prompt: "", createdAt: Date())
        
        // Get the target app (previous frontmost app)
        let targetApp = AppDetectionService.shared.getTargetApp()

        modal = CaptureModalWindowController(session: session, targetApp: targetApp) { [weak self] result in
            self?.modal = nil  // Clear reference when modal closes
            switch result {
            case .cancelled:
                AppLog.log(.info, "capture", "Modal result: cancelled")
                break
            case .pasted(_, _):
                AppLog.log(.info, "capture", "Modal result: pasted")
                // HUD is shown in the window controller
                break
            case .saved:
                AppLog.log(.info, "capture", "Modal result: saved")
                // HUD is shown in the window controller
                break
            case .pasteFailed(let message):
                AppLog.log(.warn, "capture", "Modal result: pasteFailed message=\(message)")
                HUDService.shared.show(message: message, style: .error)
            case .saveFailed(let message):
                AppLog.log(.warn, "capture", "Modal result: saveFailed message=\(message)")
                HUDService.shared.show(message: message, style: .error)
            }
        }

        modal?.show()
    }
}


