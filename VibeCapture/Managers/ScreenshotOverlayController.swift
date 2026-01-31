import AppKit

final class ScreenshotOverlayController {
    /// Completion callback receives: selection rect, overlay window ID, and a cleanup callback.
    /// The cleanup callback MUST be called after screenshot capture is complete to close overlay windows.
    typealias Completion = (CGRect?, CGWindowID?, @escaping () -> Void) -> Void

    private var windows: [OverlayWindow] = []
    private var completion: Completion?

    private var startPoint: CGPoint?
    private var startScreen: NSScreen?
    private var selectionRectGlobal: CGRect?

    private var cursorWasSet = false
    private var isFinishing = false
    private var globalKeyMonitor: Any?

    func start(completion: @escaping Completion) {
        AppLog.log(.info, "overlay", "start")
        stop()

        self.completion = completion
        isFinishing = false

        // Create one overlay window per screen (macOS can't render a single window across multiple displays)
        for screen in NSScreen.screens {
            let win = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            win.setFrame(screen.frame, display: true)
            win.controller = self
            windows.append(win)
        }

        NSCursor.crosshair.push()
        cursorWasSet = true

        // Show all windows without activating the app
        for win in windows {
            win.orderFrontRegardless()
            win.overlayView.window?.makeFirstResponder(win.overlayView)
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
        }

        // Initialize cursor position display
        updateCursorPosition()
    }

    func stop() {
        AppLog.log(.info, "overlay", "stop")
        isFinishing = false

        for win in windows {
            win.controller = nil
            win.close()
        }
        windows.removeAll()

        completion = nil
        startPoint = nil
        startScreen = nil
        selectionRectGlobal = nil

        if cursorWasSet {
            NSCursor.pop()
            cursorWasSet = false
        }

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }

    func handleMouseDown() {
        guard !isFinishing else { return }
        let p = NSEvent.mouseLocation
        AppLog.log(.debug, "overlay", "mouseDown x=\(Int(p.x)) y=\(Int(p.y))")
        startPoint = p
        startScreen = NSScreen.screens.first(where: { $0.frame.contains(p) })
        selectionRectGlobal = nil
        updateSelection()
    }

    func handleMouseDragged() {
        guard !isFinishing else { return }
        guard let startPoint, let startScreen else { return }
        let current = clamp(point: NSEvent.mouseLocation, to: startScreen.frame)
        let rect = CGRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        )
        selectionRectGlobal = rect
        updateSelection()
    }

    func handleMouseUp() {
        guard !isFinishing else { return }
        defer { updateSelection() }
        guard let rect = selectionRectGlobal else {
            AppLog.log(.info, "overlay", "mouseUp without selection -> cancel")
            finish(nil)
            return
        }

        if rect.width < 5 || rect.height < 5 {
            AppLog.log(.info, "overlay", "mouseUp tiny selection -> cancel w=\(Int(rect.width)) h=\(Int(rect.height))")
            finish(nil)
            return
        }

        AppLog.log(.info, "overlay", "mouseUp selection w=\(Int(rect.width)) h=\(Int(rect.height))")
        finish(rect)
    }

    func handleKeyDown(_ event: NSEvent) {
        guard !isFinishing else { return }
        // Esc cancels.
        if event.keyCode == 53 {
            AppLog.log(.info, "overlay", "keyDown ESC -> cancel")
            finish(nil)
        }
    }

    func handleMouseMoved() {
        guard !isFinishing else { return }
        updateCursorPosition()
    }

    private func finish(_ rect: CGRect?) {
        guard !isFinishing else { return }
        isFinishing = true

        let completion = self.completion
        
        // IMPORTANT: Get overlay window ID while windows are still on screen.
        // This ID is passed to CGWindowListCreateImage with .optionOnScreenBelowWindow,
        // which captures only windows below the overlay, effectively excluding it.
        // This is the standard technique used by professional screenshot tools to avoid
        // capturing their own UI elements.
        let overlayWindowID: CGWindowID? = windows.first.map { CGWindowID($0.windowNumber) }
        
        AppLog.log(.debug, "overlay", "finish; rect=\(rect.map { "\($0)" } ?? "nil"), overlayWindowID=\(overlayWindowID ?? 0)")

        // Pass a cleanup callback to the completion handler.
        // The caller MUST invoke this callback after screenshot capture is complete.
        // This ensures the overlay windows remain visible during capture so that
        // .optionOnScreenBelowWindow can properly exclude them.
        completion?(rect, overlayWindowID) { [weak self] in
            DispatchQueue.main.async {
                self?.stop()
            }
        }
    }

    private func updateSelection() {
        let globalRect = selectionRectGlobal
        for win in windows {
            if let globalRect {
                // Convert global rect to this window's local coordinates
                let local = globalRect.offsetBy(dx: -win.frame.origin.x, dy: -win.frame.origin.y)
                // Only show selection if it intersects this window
                if win.frame.intersects(globalRect) {
                    win.overlayView.selectionRect = local
                    win.overlayView.selectionSize = globalRect.size
                } else {
                    win.overlayView.selectionRect = nil
                    win.overlayView.selectionSize = nil
                }
            } else {
                win.overlayView.selectionRect = nil
                win.overlayView.selectionSize = nil
            }
        }
        // Also update cursor position during drag
        updateCursorPosition()
    }

    private func updateCursorPosition() {
        let globalPos = NSEvent.mouseLocation
        for win in windows {
            if win.frame.contains(globalPos) {
                let localPos = CGPoint(x: globalPos.x - win.frame.origin.x, y: globalPos.y - win.frame.origin.y)
                win.overlayView.cursorPosition = localPos
                win.overlayView.cursorGlobalPosition = globalPos
            } else {
                win.overlayView.cursorPosition = nil
                win.overlayView.cursorGlobalPosition = nil
            }
        }
    }

    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: max(rect.minX, min(point.x, rect.maxX)),
            y: max(rect.minY, min(point.y, rect.maxY))
        )
    }
}

final class OverlayWindow: NSPanel {
    let overlayView: OverlayView
    weak var controller: ScreenshotOverlayController?

    /// Important: NSWindow's `init(contentRect:...screen:)` dispatches to
    /// `init(contentRect:styleMask:backing:defer:)` on `self` internally.
    /// If we don't override the designated initializer, macOS will trap at runtime.
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        overlayView = OverlayView(frame: CGRect(origin: .zero, size: contentRect.size))
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        commonInit()
    }

    required init?(coder: NSCoder) { nil }

    private func commonInit() {
        // CRITICAL: In Swift/ARC, we must disable isReleasedWhenClosed.
        // Otherwise close() triggers a Cocoa release AND window = nil triggers
        // an ARC release, causing over-release and crash in autorelease pool drain.
        isReleasedWhenClosed = false

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true  // Enable mouse moved events for coordinate display
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = overlayView

        overlayView.onMouseDown = { [weak self] in self?.controller?.handleMouseDown() }
        overlayView.onMouseDragged = { [weak self] in self?.controller?.handleMouseDragged() }
        overlayView.onMouseUp = { [weak self] in self?.controller?.handleMouseUp() }
        overlayView.onKeyDown = { [weak self] event in self?.controller?.handleKeyDown(event) }
        overlayView.onMouseMoved = { [weak self] in self?.controller?.handleMouseMoved() }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayView: NSView {
    var selectionRect: CGRect? {
        didSet { needsDisplay = true }
    }

    /// Current mouse position in local coordinates (for coordinate display)
    var cursorPosition: CGPoint? {
        didSet { needsDisplay = true }
    }

    /// Global mouse position (for display in label)
    var cursorGlobalPosition: CGPoint?

    /// Selection size for display during drag
    var selectionSize: CGSize?

    var onMouseDown: (() -> Void)?
    var onMouseDragged: (() -> Void)?
    var onMouseUp: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?
    var onMouseMoved: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    /// Accept first mouse click even when window is not key - critical for multi-monitor support
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    /// Always return self for hit testing to prevent mouse events from passing through
    /// to windows below the overlay (e.g., Dock icons)
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }

    override func becomeFirstResponder() -> Bool {
        NSCursor.crosshair.set()
        return super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?()
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?()
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        onMouseMoved?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.fill(bounds)

        if let selectionRect {
            // Cut out selected area.
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fill(selectionRect)
            ctx.restoreGState()

            // Border.
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(selectionRect.insetBy(dx: 1, dy: 1))

            // Draw size label near selection
            if let size = selectionSize, size.width > 0, size.height > 0 {
                let sizeText = "\(Int(size.width)) × \(Int(size.height))"
                drawInfoLabel(text: sizeText, at: CGPoint(x: selectionRect.midX, y: selectionRect.minY - 30), centered: true)
            }
        }

        // Draw cursor position label
        if let pos = cursorPosition, let globalPos = cursorGlobalPosition {
            let coordText = "X: \(Int(globalPos.x))  Y: \(Int(globalPos.y))"
            // Position label offset from cursor
            let labelPos = CGPoint(x: pos.x + 20, y: pos.y - 25)
            drawInfoLabel(text: coordText, at: labelPos, centered: false)
        }
    }

    private func drawInfoLabel(text: String, at point: CGPoint, centered: Bool) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()

        let padding: CGFloat = 6
        let cornerRadius: CGFloat = 4
        let bgWidth = textSize.width + padding * 2
        let bgHeight = textSize.height + padding

        var bgX = centered ? point.x - bgWidth / 2 : point.x
        var bgY = point.y

        // Keep label within bounds
        bgX = max(4, min(bgX, bounds.width - bgWidth - 4))
        bgY = max(4, min(bgY, bounds.height - bgHeight - 4))

        let bgRect = CGRect(x: bgX, y: bgY, width: bgWidth, height: bgHeight)

        // Draw background
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        // Draw text
        let textX = bgX + padding
        let textY = bgY + (bgHeight - textSize.height) / 2
        attrStr.draw(at: CGPoint(x: textX, y: textY))
    }
}


