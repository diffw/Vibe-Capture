import AppKit

/// A button that displays an app icon and shows a custom tooltip on hover
final class AppIconButton: NSButton {
    
    /// The app this button represents (nil for Save Image button)
    var targetApp: TargetApp?
    
    /// Whether this is a Save Image button
    var isSaveButton: Bool = false
    
    /// Tooltip text to show on hover
    var hoverText: String?
    
    /// Callback when button is clicked
    var onClick: (() -> Void)?
    
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    /// Standard icon size for the button
    static let iconSize: CGFloat = 28
    static let buttonSize: CGFloat = 36
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    convenience init(app: TargetApp) {
        self.init(frame: NSRect(x: 0, y: 0, width: Self.buttonSize, height: Self.buttonSize))
        self.targetApp = app
        self.hoverText = "Send to \(app.displayName)"
        
        if let icon = app.icon {
            let resizedIcon = resizeImage(icon, to: NSSize(width: Self.iconSize, height: Self.iconSize))
            self.image = resizedIcon
        }
    }
    
    convenience init(saveImage: NSImage?) {
        self.init(frame: NSRect(x: 0, y: 0, width: Self.buttonSize, height: Self.buttonSize))
        self.isSaveButton = true
        self.hoverText = "Save Image"
        
        if let icon = saveImage {
            let resizedIcon = resizeImage(icon, to: NSSize(width: Self.iconSize, height: Self.iconSize))
            self.image = resizedIcon
        } else {
            // Use system save icon
            let config = NSImage.SymbolConfiguration(pointSize: Self.iconSize * 0.7, weight: .medium)
            self.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")?.withSymbolConfiguration(config)
        }
    }
    
    private func setupButton() {
        bezelStyle = .regularSquare
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        wantsLayer = true
        layer?.cornerRadius = 6
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        
        target = self
        action = #selector(buttonClicked)
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isHovered {
            layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.2).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    @objc private func buttonClicked() {
        onClick?()
    }
    
    // MARK: - Tracking Area for Hover
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        
        if let text = hoverText {
            HoverTooltipView.shared.show(text: text, relativeTo: self)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        HoverTooltipView.shared.hideAfterDelay()
    }
    
    // MARK: - Helper
    
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
