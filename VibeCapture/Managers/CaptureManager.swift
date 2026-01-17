import AppKit

final class CaptureManager {
    private let overlay = ScreenshotOverlayController()
    private let captureService = ScreenCaptureService()

    private var modal: CaptureModalWindowController?

    func startCapture() {
        guard captureService.ensurePermissionOrRequest() else {
            PermissionsUI.showScreenRecordingPermissionAlert()
            return
        }
        
        // Record the current frontmost app before showing overlay
        AppDetectionService.shared.recordCurrentAppAsPrevious()

        overlay.start { [weak self] rect, belowWindowID in
            guard let self, let rect else { return }

            do {
                let image = try self.captureService.capture(rect: rect, belowWindowID: belowWindowID)
                self.presentModal(with: image)
            } catch {
                HUDService.shared.show(message: error.localizedDescription, style: .error)
            }
        }
    }

    private func presentModal(with image: NSImage) {
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
                break
            case .pasted(_, _):
                // HUD is shown in the window controller
                break
            case .saved:
                // HUD is shown in the window controller
                break
            case .pasteFailed(let message):
                HUDService.shared.show(message: message, style: .error)
            case .saveFailed(let message):
                HUDService.shared.show(message: message, style: .error)
            }
        }

        modal?.show()
    }
}


