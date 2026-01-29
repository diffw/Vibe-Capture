import AppKit

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

final class RoundedHoverButton: NSButton {
    struct Style {
        let background: NSColor
        let hoverBackground: NSColor
        let pressedBackground: NSColor
        let borderColor: NSColor?
        let borderWidth: CGFloat
        let titleColor: NSColor
    }

    var style: Style? {
        didSet { updateAppearance() }
    }
    var cornerRadius: CGFloat = 8 {
        didSet { layer?.cornerRadius = cornerRadius }
    }
    var contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12) {
        didSet { invalidateIntrinsicContentSize() }
    }
    var fixedHeight: CGFloat = 32 {
        didSet { invalidateIntrinsicContentSize() }
    }
    var imageTitleSpacing: CGFloat = 6 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var title: String {
        didSet { updateAppearance() }
    }

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        imagePosition = .imageLeading
        imageHugsTitle = true
        imageScaling = .scaleProportionallyDown
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
        super.mouseDown(with: event)
        isPressed = false
        updateAppearance()
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = cornerRadius
    }

    override var intrinsicContentSize: NSSize {
        let titleSize = attributedTitle.size()
        let imageSize = image?.size ?? .zero
        let hasImage = image != nil
        let hasTitle = !title.isEmpty
        let spacing = (hasImage && hasTitle && imagePosition == .imageLeading) ? imageTitleSpacing : 0
        let width = contentInsets.left + contentInsets.right + imageSize.width + spacing + titleSize.width
        return NSSize(width: ceil(width), height: fixedHeight)
    }

    override func drawFocusRingMask() {
        // No focus ring
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let style else {
            super.draw(dirtyRect)
            return
        }
        
        // Background is drawn by layer, we only draw content here
        let imageSize = image?.size ?? .zero
        let titleSize = attributedTitle.size()
        let hasImage = image != nil
        let hasTitle = !title.isEmpty
        let spacing = (hasImage && hasTitle) ? imageTitleSpacing : 0
        
        let totalContentWidth = imageSize.width + spacing + titleSize.width
        var currentX = contentInsets.left
        
        // Center content horizontally
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        if totalContentWidth < availableWidth {
            currentX += (availableWidth - totalContentWidth) / 2
        }
        
        // Draw image
        if let img = image {
            let imageY = (bounds.height - imageSize.height) / 2
            let imageRect = NSRect(x: currentX, y: imageY, width: imageSize.width, height: imageSize.height)
            
            if img.isTemplate {
                let tintedImage = img.tinted(with: style.titleColor)
                tintedImage.draw(in: imageRect)
            } else {
                img.draw(in: imageRect)
            }
            currentX += imageSize.width + spacing
        }
        
        // Draw title
        if hasTitle {
            let titleY = (bounds.height - titleSize.height) / 2
            let titleRect = NSRect(x: currentX, y: titleY, width: titleSize.width, height: titleSize.height)
            attributedTitle.draw(in: titleRect)
        }
    }

    private func updateAppearance() {
        guard let style else { return }
        let backgroundColor: NSColor
        if isPressed {
            backgroundColor = style.pressedBackground
        } else if isHovered {
            backgroundColor = style.hoverBackground
        } else {
            backgroundColor = style.background
        }
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = style.borderColor?.cgColor
        layer?.borderWidth = style.borderWidth

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.titleColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
        contentTintColor = style.titleColor
    }
}
