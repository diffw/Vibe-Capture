import AppKit

final class DraggableImageView: NSImageView, NSDraggingSource {
    var fileURL: URL?
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard let fileURL, let image = image else { return }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: image)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        onDragStarted?()
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragEnded?()
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
