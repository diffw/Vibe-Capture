import AppKit

enum CaptureModalResult {
    case cancelled
    case copied(didSave: Bool)
    case copyFailed(message: String)
}

final class CaptureModalWindowController: NSWindowController, NSWindowDelegate {
    private let session: CaptureSession
    private let onResult: (CaptureModalResult) -> Void

    private var didFinish = false
    private var keyMonitor: Any?

    private let viewController: CaptureModalViewController

    init(session: CaptureSession, onResult: @escaping (CaptureModalResult) -> Void) {
        self.session = session
        self.onResult = onResult
        self.viewController = CaptureModalViewController(session: session)

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
        viewController.onCopy = { [weak self] prompt in
            self?.copyAndClose(prompt: prompt)
        }
        viewController.onCommandEnter = { [weak self] in
            self?.copyAndClose(prompt: self?.viewController.promptText ?? "")
        }
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }

        // Calculate the correct window size before showing
        let windowSize = Self.calculateWindowSize(for: session.image.size)
        window.setContentSize(windowSize)

        NSApp.activate(ignoringOtherApps: true)
        centerWindowOnCurrentScreen(window, expectedSize: windowSize)
        window.makeKeyAndOrderFront(nil)
        viewController.focusPrompt()
    }

    /// Center window on the screen containing the mouse cursor
    private func centerWindowOnCurrentScreen(_ window: NSWindow, expectedSize: NSSize) {
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = currentScreen else {
            window.center()
            return
        }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - expectedSize.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - expectedSize.height) / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.finish(.cancelled)
                return nil
            }
            if event.modifierFlags.contains(.command), (event.keyCode == 36 || event.keyCode == 76) { // ⌘↩︎
                self.copyAndClose(prompt: self.viewController.promptText)
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

    private func copyAndClose(prompt: String) {
        let image = session.image

        // Close the modal immediately so it doesn't interfere with Cursor
        finish(.copied(didSave: false))

        // Use AutoPasteService to paste image + text to Cursor
        AutoPasteService.shared.pasteToСursor(image: image, text: prompt) { success, errorMessage in
            if success {
                HUDService.shared.show(message: "Pasted to Cursor", style: .success)
            } else if let errorMessage {
                HUDService.shared.show(message: errorMessage, style: .error)
            }

            // Attempt save (if enabled)
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

    private static func calculateWindowSize(for imageSize: NSSize) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 600, height: 500)
        }

        let aspectRatio = imageSize.width / imageSize.height

        // Start with max image height, calculate width from aspect ratio
        var imageDisplayHeight = min(imageSize.height, maxImageHeight)
        var imageDisplayWidth = imageDisplayHeight * aspectRatio

        // Clamp width to min/max window width (accounting for padding)
        let contentWidth = imageDisplayWidth
        let windowWidth = contentWidth + padding * 2

        if windowWidth > maxWindowWidth {
            // Too wide: constrain to max width
            imageDisplayWidth = maxWindowWidth - padding * 2
            imageDisplayHeight = imageDisplayWidth / aspectRatio
        } else if windowWidth < minWindowWidth {
            // Too narrow: expand to min width
            imageDisplayWidth = minWindowWidth - padding * 2
            // Keep original image height (don't stretch)
            imageDisplayHeight = min(imageDisplayWidth / aspectRatio, maxImageHeight)
        }

        let finalWindowWidth = max(minWindowWidth, min(maxWindowWidth, imageDisplayWidth + padding * 2))
        let finalWindowHeight = imageDisplayHeight + promptAreaHeight + buttonsRowHeight + padding * 2 + spacing * 2

        return NSSize(width: finalWindowWidth, height: finalWindowHeight)
    }
}


