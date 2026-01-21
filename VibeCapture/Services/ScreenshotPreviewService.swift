import AppKit

final class ScreenshotPreviewService {
    static let shared = ScreenshotPreviewService()
    private init() {}

    private var previewController: ScreenshotPreviewPanelController?

    func showPreview(image: NSImage, fileURL: URL?) {
        previewController?.closePreview()
        let controller = ScreenshotPreviewPanelController(image: image, fileURL: fileURL) { [weak self] in
            self?.previewController = nil
        }
        previewController = controller
        controller.show()
    }

    func updatePreviewFileURL(_ url: URL?) {
        previewController?.updateFileURL(url)
    }

    func dismissPreview() {
        previewController?.closePreview()
        previewController = nil
    }
}
