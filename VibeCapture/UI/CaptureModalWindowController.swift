import AppKit

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

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = viewController

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
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.finish(.cancelled)
                return nil
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
        let image = session.image
        let appName = targetApp.displayName

        // Close the modal immediately so it doesn't interfere with target app
        finish(.pasted(toApp: appName, didSave: false))

        // Use AutoPasteService to paste image + text to target app
        AutoPasteService.shared.pasteToApp(image: image, text: prompt, targetApp: targetApp) { success, errorMessage in
            if success {
                HUDService.shared.show(message: "Pasted to \(appName)", style: .success)
            } else if let errorMessage {
                HUDService.shared.show(message: errorMessage, style: .error)
            }

            // Attempt auto-save (if enabled)
            DispatchQueue.main.async {
                do {
                    let saved = try ScreenshotSaveService.shared.saveIfEnabled(image: image)
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
        let image = session.image
        
        do {
            let saved = try ScreenshotSaveService.shared.saveScreenshot(image: image)
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
    private static let maxWindowWidth: CGFloat = 800
    private static let maxImageHeight: CGFloat = 400
    private static let promptAreaHeight: CGFloat = 140
    private static let buttonsRowHeight: CGFloat = 40
    private static let padding: CGFloat = 16
    private static let spacing: CGFloat = 12
    private static let imageContainerPadding: CGFloat = 12

    private static func calculateWindowSize(for imageSize: NSSize) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 600, height: 500)
        }

        let aspectRatio = imageSize.width / imageSize.height

        // Start with max image height, calculate width from aspect ratio
        var imageDisplayHeight = min(imageSize.height, maxImageHeight)
        var imageDisplayWidth = imageDisplayHeight * aspectRatio

        // Clamp width to min/max window width (accounting for padding + container padding)
        let totalHorizontalPadding = padding * 2 + imageContainerPadding * 2
        let windowWidth = imageDisplayWidth + totalHorizontalPadding

        if windowWidth > maxWindowWidth {
            // Too wide: constrain to max width
            imageDisplayWidth = maxWindowWidth - totalHorizontalPadding
            imageDisplayHeight = imageDisplayWidth / aspectRatio
        } else if windowWidth < minWindowWidth {
            // Too narrow: expand to min width
            imageDisplayWidth = minWindowWidth - totalHorizontalPadding
            // Keep original image height (don't stretch)
            imageDisplayHeight = min(imageDisplayWidth / aspectRatio, maxImageHeight)
        }

        let finalWindowWidth = max(minWindowWidth, min(maxWindowWidth, imageDisplayWidth + totalHorizontalPadding))
        // Add container padding to height as well
        let imageContainerHeight = imageDisplayHeight + imageContainerPadding * 2
        let finalWindowHeight = imageContainerHeight + promptAreaHeight + buttonsRowHeight + padding * 2 + spacing * 2

        return NSSize(width: finalWindowWidth, height: finalWindowHeight)
    }
}


