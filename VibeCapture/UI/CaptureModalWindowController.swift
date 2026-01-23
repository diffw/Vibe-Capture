import AppKit

/// Custom NSWindow subclass that allows borderless windows to become key and accept input
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum CaptureModalResult {
    case cancelled
    case pasted(toApp: String, didSave: Bool)
    case saved
    case pasteFailed(message: String)
    case saveFailed(message: String)
}

final class CaptureModalWindowController: NSWindowController, NSWindowDelegate {
    private let session: CaptureSession
    private let onResult: (CaptureModalResult) -> Void
    private let targetApp: TargetApp?

    private var didFinish = false
    private var keyMonitor: Any?

    private let viewController: CaptureModalViewController

    init(session: CaptureSession, targetApp: TargetApp?, onResult: @escaping (CaptureModalResult) -> Void) {
        self.session = session
        self.targetApp = targetApp
        self.onResult = onResult
        self.viewController = CaptureModalViewController(session: session, targetApp: targetApp)

        // Calculate window size based on image aspect ratio (like macOS Screenshot preview)
        let windowSize = Self.calculateWindowSize(for: session.image.size)

        let window = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = viewController
        
        // Apply rounded corners to the window content view (match macOS system windows)
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12  // macOS system window style
            contentView.layer?.masksToBounds = true
            contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }

        super.init(window: window)

        window.delegate = self

        viewController.onClose = { [weak self] in
            self?.finish(.cancelled)
        }
        viewController.onPaste = { [weak self] prompt, targetApp in
            self?.pasteAndClose(prompt: prompt, targetApp: targetApp)
        }
        viewController.onSave = { [weak self] in
            self?.saveScreenshot()
        }
        viewController.onCommandEnter = { [weak self] in
            guard let self,
                  let targetApp = self.viewController.currentTargetApp,
                  AppDetectionService.shared.isWhitelisted(targetApp) else {
                return
            }
            self.pasteAndClose(prompt: self.viewController.promptText, targetApp: targetApp)
        }
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }

        // Calculate the correct window size before showing
        let contentSize = Self.calculateWindowSize(for: session.image.size)
        window.setContentSize(contentSize)

        // Force layout to get accurate frame size
        window.layoutIfNeeded()

        NSApp.activate(ignoringOtherApps: true)
        centerWindowOnCurrentScreen(window)
        window.makeKeyAndOrderFront(nil)
        viewController.focusPrompt()
    }
    
    override func close() {
        finish(.cancelled)
    }

    /// Center window on the screen containing the mouse cursor
    private func centerWindowOnCurrentScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = currentScreen else {
            window.center()
            return
        }

        // Use actual frame size (includes title bar) for accurate centering
        let windowFrame = window.frame
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, let window = self.window else { return event }
            
            // Only handle events if this window is the key window
            guard window.isKeyWindow else { return event }
            
            if event.keyCode == 53 { // Esc
                // First try to cancel annotation creation, otherwise close modal
                self.viewController.cancelAnnotationCreation()
                self.finish(.cancelled)
                return nil
            }
            if event.keyCode == 51 || event.keyCode == 117 { // Delete/Backspace or Forward Delete
                // Delete selected annotation (only if text view is not first responder)
                if !(window.firstResponder is NSTextView) {
                    self.viewController.deleteSelectedAnnotation()
                    return nil
                }
            }
            if event.modifierFlags.contains(.command), (event.keyCode == 36 || event.keyCode == 76) { // ⌘↩︎
                // Trigger paste via the onCommandEnter callback (which checks whitelist)
                self.viewController.onCommandEnter?()
                return nil
            }
            return event
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !didFinish {
            finish(.cancelled)
        }
    }

    private func pasteAndClose(prompt: String, targetApp: TargetApp) {
        let appName = targetApp.displayName

        // Preflight: We need Accessibility permission to simulate ⌘+V.
        // If missing, prompt the user and keep the modal open so they can retry.
        guard AutoPasteService.shared.hasAccessibilityPermission else {
            AutoPasteService.shared.requestAccessibilityPermission()
            NSApp.activate(ignoringOtherApps: true)
            HUDService.shared.show(message: L("permission.accessibility.message"), style: .error, duration: 3.5)
            return
        }
        
        // Composite annotations onto the image
        let annotations = viewController.annotations
        let finalImage = AnnotationRenderService.render(image: session.image, annotations: annotations)

        // Close the modal immediately so it doesn't interfere with target app
        finish(.pasted(toApp: appName, didSave: false))

        // Use AutoPasteService to paste image + text to target app
        AutoPasteService.shared.pasteToApp(image: finalImage, text: prompt, targetApp: targetApp) { success, errorMessage in
            if success {
                HUDService.shared.show(message: "Pasted to \(appName)", style: .success)
            } else if let errorMessage {
                HUDService.shared.show(message: errorMessage, style: .error)
            }

            // Attempt auto-save (if enabled)
            DispatchQueue.main.async {
                do {
                    let saved = try ScreenshotSaveService.shared.saveIfEnabled(image: finalImage)
                    if saved {
                        HUDService.shared.show(message: "Saved", style: .success)
                    }
                } catch {
                    HUDService.shared.show(message: error.localizedDescription, style: .error)
                }
            }
        }
    }
    
    private func saveScreenshot() {
        // Composite annotations onto the image
        let annotations = viewController.annotations
        let finalImage = AnnotationRenderService.render(image: session.image, annotations: annotations)
        
        do {
            let saved = try ScreenshotSaveService.shared.saveScreenshot(image: finalImage)
            if saved {
                HUDService.shared.show(message: "Screenshot Saved", style: .success)
            }
            // If user cancelled, don't show anything
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error)
        }
    }

    private func finish(_ result: CaptureModalResult) {
        if didFinish { return }
        didFinish = true

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        window?.orderOut(nil)
        onResult(result)
    }

    // MARK: - Window Size Calculation (macOS Screenshot Preview style)

    private static let minWindowWidth: CGFloat = 400
    private static let promptAreaHeight: CGFloat = 60  // ~3 lines
    private static let buttonsRowHeight: CGFloat = 40
    private static let toolbarHeight: CGFloat = 36
    private static let padding: CGFloat = 16
    private static let spacing: CGFloat = 12
    
    /// Write debug log to desktop
    private static func writeLog(_ message: String) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/vibecap_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: desktop.path) {
                if let handle = try? FileHandle(forWritingTo: desktop) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: desktop)
            }
        }
    }
    
    /// Calculate max window dimensions based on screen size (similar to Mac Screenshot behavior)
    private static func calculateMaxDimensions() -> (maxWidth: CGFloat, maxImageHeight: CGFloat) {
        guard let screen = NSScreen.main else {
            writeLog("WC: No main screen, using fallback (800, 400)")
            return (800, 400)  // Fallback
        }
        
        let screenFrame = screen.visibleFrame
        
        // Max window width: 90% of screen width
        let maxWidth = screenFrame.width * 0.90
        
        // Max window height: 90% of screen height
        // Subtract UI chrome to get max image height
        let maxWindowHeight = screenFrame.height * 0.90
        let uiChromeHeight = promptAreaHeight + buttonsRowHeight + toolbarHeight + padding * 2 + spacing * 2 + 36
        let maxImageHeight = maxWindowHeight - uiChromeHeight
        
        writeLog("WC: Screen=\(screenFrame.width)x\(screenFrame.height), maxWidth=\(maxWidth), maxImageHeight=\(maxImageHeight)")
        
        return (max(maxWidth, 400), max(maxImageHeight, 300))
    }

    private static func calculateWindowSize(for imageSize: NSSize) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 600, height: 500)
        }
        
        let (maxWindowWidth, maxImageHeight) = calculateMaxDimensions()
        let aspectRatio = imageSize.width / imageSize.height
        let totalHorizontalPadding = padding * 2
        let maxImageWidth = maxWindowWidth - totalHorizontalPadding

        var imageDisplayWidth: CGFloat
        var imageDisplayHeight: CGFloat
        
        // Calculate both possibilities and pick the one that fits best
        // Option 1: Fill max width, calculate height
        let widthFirstHeight = maxImageWidth / aspectRatio
        // Option 2: Fill max height, calculate width  
        let heightFirstWidth = maxImageHeight * aspectRatio
        
        if widthFirstHeight <= maxImageHeight {
            // Width-first fits within height limit - use it (better for wide images)
            imageDisplayWidth = maxImageWidth
            imageDisplayHeight = widthFirstHeight
        } else if heightFirstWidth <= maxImageWidth {
            // Height-first fits within width limit - use it (better for tall images)
            imageDisplayWidth = heightFirstWidth
            imageDisplayHeight = maxImageHeight
        } else {
            // Both exceed limits - constrain by the tighter dimension
            imageDisplayWidth = maxImageWidth
            imageDisplayHeight = maxImageHeight
        }
        
        // Don't exceed original image size
        if imageDisplayWidth > imageSize.width {
            imageDisplayWidth = imageSize.width
            imageDisplayHeight = imageDisplayWidth / aspectRatio
        }
        if imageDisplayHeight > imageSize.height {
            imageDisplayHeight = imageSize.height
            imageDisplayWidth = imageDisplayHeight * aspectRatio
        }
        
        // Ensure minimum width
        let windowWidth = imageDisplayWidth + totalHorizontalPadding
        if windowWidth < minWindowWidth {
            imageDisplayWidth = minWindowWidth - totalHorizontalPadding
            imageDisplayHeight = min(imageDisplayWidth / aspectRatio, maxImageHeight)
        }

        let finalWindowWidth = max(minWindowWidth, min(maxWindowWidth, imageDisplayWidth + totalHorizontalPadding))
        // Image container includes: 16px top + image + 12px gap + 36px toolbar + 8px bottom
        let imageContainerHeight = 16 + imageDisplayHeight + 12 + toolbarHeight + 8
        // Total: image container + 12px spacing + prompt + buttons + padding
        let finalWindowHeight = imageContainerHeight + spacing + promptAreaHeight + buttonsRowHeight + padding + spacing

        writeLog("WC: imageSize=\(imageSize.width)x\(imageSize.height), maxImageWidth=\(maxImageWidth), maxImageHeight=\(maxImageHeight)")
        writeLog("WC: imageDisplay=\(imageDisplayWidth)x\(imageDisplayHeight), finalWindow=\(finalWindowWidth)x\(finalWindowHeight)")
        
        return NSSize(width: finalWindowWidth, height: finalWindowHeight)
    }
}


