import AppKit

final class ScreenshotPreviewPanelController: NSWindowController {
    private let imageView = DraggableImageView()
    private let closeButton = CountdownCloseButton()
    private let showInFinderButton = NSButton(title: "Show in Finder", target: nil, action: nil)
    private let thumbnailSize: NSSize
    private var fileURL: URL?
    private let autoCloseDuration: TimeInterval = 5.0
    private let onClose: () -> Void

    init(image: NSImage, fileURL: URL?, onClose: @escaping () -> Void) {
        self.thumbnailSize = Self.makeThumbnailSize(for: image.size)
        self.fileURL = fileURL
        self.onClose = onClose
        super.init(window: nil)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: thumbnailSize.width, height: thumbnailSize.height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let contentView = PreviewContainerView()
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.onHoverChanged = { [weak self] isHovering in
            if isHovering {
                self?.closeButton.pause()
            } else {
                self?.closeButton.resume()
            }
        }
        panel.contentView = contentView

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.fileURL = fileURL
        imageView.onDragStarted = { [weak self] in self?.closeButton.pause() }
        imageView.onDragEnded = { [weak self] in self?.closeButton.resume() }

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.onTimeout = { [weak self] in
            self?.closePreview()
        }
        closeButton.target = self
        closeButton.action = #selector(closeClicked)

        showInFinderButton.translatesAutoresizingMaskIntoConstraints = false
        showInFinderButton.bezelStyle = .rounded
        showInFinderButton.controlSize = .small
        showInFinderButton.target = self
        showInFinderButton.action = #selector(showInFinderClicked)
        showInFinderButton.isEnabled = fileURL != nil

        contentView.addSubview(imageView)
        contentView.addSubview(closeButton)
        contentView.addSubview(showInFinderButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: thumbnailSize.height),
            imageView.widthAnchor.constraint(equalToConstant: thumbnailSize.width),

            closeButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 6),
            closeButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -6),
            closeButton.widthAnchor.constraint(equalToConstant: CountdownCloseButton.buttonSize),
            closeButton.heightAnchor.constraint(equalToConstant: CountdownCloseButton.buttonSize),

            showInFinderButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            showInFinderButton.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            showInFinderButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        self.window = panel
        closeButton.start(duration: autoCloseDuration)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }
        window.layoutIfNeeded()

        let screen = NSScreen.main ?? NSScreen.screens.first
        if let screen {
            let frame = screen.visibleFrame
            let contentSize = window.contentView?.fittingSize ?? window.frame.size
            window.setContentSize(contentSize)
            let windowFrame = window.frame
            let x = frame.maxX - windowFrame.width - 16
            let y = frame.minY + 16
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window.orderFrontRegardless()
    }

    func updateFileURL(_ url: URL?) {
        fileURL = url
        imageView.fileURL = url
        showInFinderButton.isEnabled = url != nil
    }

    func closePreview() {
        closeButton.stop()
        window?.orderOut(nil)
        onClose()
    }

    @objc private func closeClicked() {
        closePreview()
    }

    @objc private func showInFinderClicked() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func makeThumbnailSize(for size: NSSize) -> NSSize {
        let maxDimension: CGFloat = 256
        guard size.width > 0, size.height > 0 else {
            return NSSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(1.0, min(maxDimension / size.width, maxDimension / size.height))
        return NSSize(width: size.width * scale, height: size.height * scale)
    }
}

final class PreviewContainerView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
}
