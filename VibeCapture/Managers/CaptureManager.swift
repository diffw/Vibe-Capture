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
        let session = CaptureSession(image: image, prompt: "", createdAt: Date())

        modal = CaptureModalWindowController(session: session) { result in
            switch result {
            case .cancelled:
                break
            case .copied(let didSave):
                HUDService.shared.show(message: didSave ? "Copied & Saved" : "Copied", style: .success)
            case .copyFailed(let message):
                HUDService.shared.show(message: message, style: .error)
            }
        }

        modal?.show()
    }
}


