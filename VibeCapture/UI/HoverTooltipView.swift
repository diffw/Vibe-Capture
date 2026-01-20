import AppKit

/// A custom tooltip view with semi-transparent black background and white text
/// Appears near the cursor when hovering over UI elements
final class HoverTooltipView: NSView {
    
    private let label = NSTextField(labelWithString: "")
    private var trackingView: NSView?
    private var hideTimer: Timer?
    
    // Singleton for easy access
    static let shared = HoverTooltipView()
    
    private lazy var tooltipWindow: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 30),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .popUpMenu  // Higher level to appear above modal
        window.ignoresMouseEvents = true
        window.contentView = self
        return window
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        layer?.cornerRadius = 6
        
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }
    
    /// Show tooltip with given text near the specified view
    func show(text: String, relativeTo view: NSView, preferredEdge: NSRectEdge = .maxY) {
        hideTimer?.invalidate()
        
        label.stringValue = text
        label.sizeToFit()
        
        // Calculate tooltip size
        let textSize = label.intrinsicContentSize
        let tooltipWidth = textSize.width + 20
        let tooltipHeight = textSize.height + 12
        
        // Get view's position in screen coordinates
        guard let window = view.window else { return }
        let viewFrameInWindow = view.convert(view.bounds, to: nil)
        let viewFrameOnScreen = window.convertToScreen(viewFrameInWindow)
        
        // Position tooltip above the view, centered
        var tooltipX = viewFrameOnScreen.midX - tooltipWidth / 2
        let tooltipY = viewFrameOnScreen.maxY + 6
        
        // Keep tooltip on screen
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            if tooltipX < screenFrame.minX {
                tooltipX = screenFrame.minX + 4
            }
            if tooltipX + tooltipWidth > screenFrame.maxX {
                tooltipX = screenFrame.maxX - tooltipWidth - 4
            }
        }
        
        // Update frame and show
        self.frame = NSRect(x: 0, y: 0, width: tooltipWidth, height: tooltipHeight)
        tooltipWindow.setFrame(NSRect(x: tooltipX, y: tooltipY, width: tooltipWidth, height: tooltipHeight), display: true)
        tooltipWindow.orderFront(nil)
    }
    
    /// Hide the tooltip
    func hide() {
        hideTimer?.invalidate()
        tooltipWindow.orderOut(nil)
    }
    
    /// Hide tooltip after a delay
    func hideAfterDelay(_ delay: TimeInterval = 0.1) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

/// A button that shows a hover tooltip
class TooltipButton: NSButton {
    var tooltipText: String?
    private var trackingArea: NSTrackingArea?
    
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
        if let text = tooltipText {
            HoverTooltipView.shared.show(text: text, relativeTo: self)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        HoverTooltipView.shared.hideAfterDelay()
    }
}
