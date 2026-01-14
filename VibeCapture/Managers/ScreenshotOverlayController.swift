import AppKit

final class ScreenshotOverlayController {
    typealias Completion = (CGRect?, CGWindowID?) -> Void

    private var windows: [OverlayWindow] = []
    private var completion: Completion?

    private var startPoint: CGPoint?
    private var startScreen: NSScreen?
    private var selectionRectGlobal: CGRect?

    private var cursorWasSet = false
    private var isFinishing = false

    func start(completion: @escaping Completion) {
        stop()

        self.completion = completion
        isFinishing = false

        // Create one overlay window per screen (macOS can't render a single window across multiple displays)
        for screen in NSScreen.screens {
            let win = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            win.setFrame(screen.frame, display: true)
            win.controller = self
            windows.append(win)
        }

        NSCursor.crosshair.set()
        cursorWasSet = true

        NSApp.activate(ignoringOtherApps: true)

        // Show all windows and make the first one key
        for (i, win) in windows.enumerated() {
            if i == 0 {
                win.makeKeyAndOrderFront(nil)
                win.overlayView.window?.makeFirstResponder(win.overlayView)
            } else {
                win.orderFront(nil)
            }
        }
    }

    func stop() {
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
            NSCursor.arrow.set()
            cursorWasSet = false
        }
    }

    func handleMouseDown() {
        guard !isFinishing else { return }
        let p = NSEvent.mouseLocation
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
            finish(nil)
            return
        }

        if rect.width < 5 || rect.height < 5 {
            finish(nil)
            return
        }

        finish(rect)
    }

    func handleKeyDown(_ event: NSEvent) {
        guard !isFinishing else { return }
        // Esc cancels.
        if event.keyCode == 53 {
            finish(nil)
        }
    }

    private func finish(_ rect: CGRect?) {
        guard !isFinishing else { return }
        isFinishing = true

        let completion = self.completion

        // Defer completion + teardown to the next runloop tick.
        DispatchQueue.main.async { [weak self] in
            self?.stop()
            completion?(rect, nil)
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
                } else {
                    win.overlayView.selectionRect = nil
                }
            } else {
                win.overlayView.selectionRect = nil
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

final class OverlayWindow: NSWindow {
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
        ignoresMouseEvents = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = overlayView

        overlayView.onMouseDown = { [weak self] in self?.controller?.handleMouseDown() }
        overlayView.onMouseDragged = { [weak self] in self?.controller?.handleMouseDragged() }
        overlayView.onMouseUp = { [weak self] in self?.controller?.handleMouseUp() }
        overlayView.onKeyDown = { [weak self] event in self?.controller?.handleKeyDown(event) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayView: NSView {
    var selectionRect: CGRect? {
        didSet { needsDisplay = true }
    }

    var onMouseDown: (() -> Void)?
    var onMouseDragged: (() -> Void)?
    var onMouseUp: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.fill(bounds)

        guard let selectionRect else { return }

        // Cut out selected area.
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.fill(selectionRect)
        ctx.restoreGState()

        // Border.
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(selectionRect.insetBy(dx: 1, dy: 1))
    }
}


