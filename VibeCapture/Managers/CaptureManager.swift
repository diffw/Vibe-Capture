import AppKit

final class CaptureManager {
    private let overlay = ScreenshotOverlayController()
    private let captureService = ScreenCaptureService()

    private var modal: CaptureModalWindowController?
    private var frozenSnapshotsByDisplayID: [CGDirectDisplayID: FrozenScreenSnapshot] = [:]
    private var isStartingCapture = false

    func startCapture() {
        let span = AppLog.span("capture", "startCapture")
        defer { span.end(.info) }

        guard !isStartingCapture else {
            AppLog.log(.debug, "capture", "startCapture ignored (already starting)")
            return
        }
        isStartingCapture = true

        guard ScreenRecordingGate.ensureOrShowModal() else {
            AppLog.log(.warn, "capture", "Screen recording permission missing; showing gate modal")
            isStartingCapture = false
            return
        }
        
        // Capture frozen snapshots off the main thread and in parallel (multi-monitor optimization).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let snaps = try self.captureAllScreensFrozenSnapshotsParallel()
                DispatchQueue.main.async {
                    self.frozenSnapshotsByDisplayID = snaps
                    let frozenBackgrounds: [CGDirectDisplayID: NSImage] = snaps.mapValues { $0.nsImage }

                    AppLog.log(.info, "capture", "Starting overlay selection (frozen background)")

                    self.overlay.start(frozenBackgroundsByDisplayID: frozenBackgrounds) { [weak self] rect, startDisplayID, cleanup in
                        guard let self, let rect, let startDisplayID else {
                            cleanup()
                            self?.frozenSnapshotsByDisplayID = [:]
                            self?.isStartingCapture = false
                            return
                        }
                        self.cropFromFrozenSnapshot(rect, startDisplayID: startDisplayID, cleanup: cleanup)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    AppLog.log(.error, "capture", "Failed to capture frozen snapshot: \(error)")
                    self.isStartingCapture = false
                    HUDService.shared.show(message: error.localizedDescription, style: .error)
                }
            }
        }
    }

    private func cropFromFrozenSnapshot(_ rect: CGRect, startDisplayID: CGDirectDisplayID, cleanup: @escaping () -> Void) {
        let span = AppLog.span("capture", "cropFromFrozenSnapshot", meta: [
            "w": Int(rect.width),
            "h": Int(rect.height),
            "x": Int(rect.origin.x),
            "y": Int(rect.origin.y),
        ])

        do {
            guard let snapshot = frozenSnapshotsByDisplayID[startDisplayID] else {
                throw ScreenCaptureError.captureFailed
            }

            let image = try crop(snapshot: snapshot, selectionRectInScreenPoints: rect)
            span.end(.info, extra: ["result": "ok"])
            
            // Close overlay now that we have the final image.
            cleanup()
            frozenSnapshotsByDisplayID = [:]
            isStartingCapture = false
            
            presentModal(with: image)
        } catch {
            span.end(.error, extra: ["result": "error", "error": String(describing: error)])
            cleanup()
            frozenSnapshotsByDisplayID = [:]
            isStartingCapture = false
            HUDService.shared.show(message: error.localizedDescription, style: .error)
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

        modal = CaptureModalWindowController(session: session) { [weak self] result in
            self?.modal = nil  // Clear reference when modal closes
            switch result {
            case .cancelled:
                AppLog.log(.info, "capture", "Modal result: cancelled")
                break
            case .saved:
                AppLog.log(.info, "capture", "Modal result: saved")
                // HUD is shown in the window controller
                break
            case .saveFailed(let message):
                AppLog.log(.warn, "capture", "Modal result: saveFailed message=\(message)")
                HUDService.shared.show(message: message, style: .error)
            }
        }

        modal?.show()
    }

    private func captureAllScreensFrozenSnapshotsParallel() throws -> [CGDirectDisplayID: FrozenScreenSnapshot] {
        let screens = NSScreen.screens
        var result: [CGDirectDisplayID: FrozenScreenSnapshot] = [:]
        var firstError: Error?
        let lock = NSLock()
        let group = DispatchGroup()

        for screen in screens {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                defer { group.leave() }
                guard let self else { return }
                do {
                    let snap = try self.captureService.captureFrozenSnapshot(for: screen)
                    lock.lock()
                    result[snap.displayID] = snap
                    lock.unlock()
                } catch {
                    lock.lock()
                    if firstError == nil { firstError = error }
                    lock.unlock()
                }
            }
        }

        group.wait()

        if let firstError { throw firstError }
        return result
    }

    private func crop(snapshot: FrozenScreenSnapshot, selectionRectInScreenPoints: CGRect) throws -> NSImage {
        let cropRectPx = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selectionRectInScreenPoints,
            screenFrameInScreenPoints: snapshot.screenFramePoints,
            imagePixelSize: CGSize(width: snapshot.cgImage.width, height: snapshot.cgImage.height),
            backingScaleFactor: snapshot.backingScaleFactor
        )

        guard let cropRectPx else { throw ScreenCaptureError.captureFailed }
        guard let cropped = snapshot.cgImage.cropping(to: cropRectPx) else { throw ScreenCaptureError.captureFailed }

        // The resulting NSImage size should be expressed in points (selection size), not pixels.
        return NSImage(cgImage: cropped, size: selectionRectInScreenPoints.size)
    }
}


