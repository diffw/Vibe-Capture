import AppKit

final class CaptureModalViewController: NSViewController, NSTextViewDelegate, AnnotationToolbarViewDelegate, AnnotationCanvasViewDelegate {
    var onClose: (() -> Void)?
    var onPaste: ((String, TargetApp) -> Void)?
    var onSave: (() -> Void)?
    var onCommandEnter: (() -> Void)?

    private let session: CaptureSession
    private let imageDisplayHeight: CGFloat

    private let imageContainerView = NSView()
    private let imageWrapper = NSView()  // Wrapper for rounded corners mask
    private let imageView = NSImageView()
    private let annotationCanvasView = AnnotationCanvasView()
    private let annotationToolbar = AnnotationToolbarView()
    private let promptScrollView = FocusableScrollView()
    private let promptTextView = PromptTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    
    // Split button for Send
    private let sendButton = NSButton(title: "Send to App", target: nil, action: nil)
    private let dropdownButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let escHintLabel = NSTextField(labelWithString: "ESC to close")
    
    /// Currently selected target app
    private var selectedTargetApp: TargetApp?
    
    /// Whether the current app is optimized (in whitelist)
    private var isAppOptimized: Bool {
        guard let app = selectedTargetApp else { return false }
        return AppDetectionService.shared.isWhitelisted(app)
    }
    
    /// Whether the current app is blacklisted (doesn't support paste)
    private var isAppBlacklisted: Bool {
        guard let app = selectedTargetApp else { return false }
        return AppDetectionService.shared.isBlacklisted(app)
    }
    
    /// Whether we have a valid target app to send to (not blacklisted)
    private var canSendToApp: Bool {
        guard let _ = selectedTargetApp else { return false }
        return !isAppBlacklisted
    }
    
    /// Brand color for active send button
    private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76

    init(session: CaptureSession, targetApp: TargetApp?) {
        self.session = session
        self.selectedTargetApp = targetApp
        // Calculate image display height based on aspect ratio
        self.imageDisplayHeight = Self.calculateImageHeight(for: session.image.size)
        super.init(nibName: nil, bundle: nil)
    }

    private static func calculateImageHeight(for imageSize: NSSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 280 }

        // Get dynamic max dimensions based on screen size
        let (maxWindowWidth, maxHeight) = calculateMaxDimensions()
        let minWidth: CGFloat = 400 - 32 // minWindowWidth - padding
        let maxWidth: CGFloat = maxWindowWidth - 32 // maxWindowWidth - padding

        let aspectRatio = imageSize.width / imageSize.height
        
        var width: CGFloat
        var height: CGFloat
        
        // Calculate both possibilities and pick the one that fits best
        // Option 1: Fill max width, calculate height
        let widthFirstHeight = maxWidth / aspectRatio
        // Option 2: Fill max height, calculate width  
        let heightFirstWidth = maxHeight * aspectRatio
        
        if widthFirstHeight <= maxHeight {
            // Width-first fits within height limit - use it (better for wide images)
            width = maxWidth
            height = widthFirstHeight
        } else if heightFirstWidth <= maxWidth {
            // Height-first fits within width limit - use it (better for tall images)
            width = heightFirstWidth
            height = maxHeight
        } else {
            // Both exceed limits - constrain by the tighter dimension
            width = maxWidth
            height = maxHeight
        }
        
        // Don't exceed original image size
        if width > imageSize.width {
            width = imageSize.width
            height = width / aspectRatio
        }
        if height > imageSize.height {
            height = imageSize.height
            width = height * aspectRatio
        }
        
        // Ensure minimum width
        if width < minWidth {
            width = minWidth
            height = min(width / aspectRatio, maxHeight)
        }

        writeLog("VC: imageSize=\(imageSize.width)x\(imageSize.height), maxWidth=\(maxWidth), maxHeight=\(maxHeight), display=\(width)x\(height)")
        return height
    }
    
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
    
    /// Calculate max dimensions based on screen size (mirrors WindowController logic)
    private static func calculateMaxDimensions() -> (maxWidth: CGFloat, maxHeight: CGFloat) {
        guard let screen = NSScreen.main else {
            writeLog("VC: No main screen, using fallback (800, 400)")
            return (800, 400)  // Fallback
        }
        
        let screenFrame = screen.visibleFrame
        
        // Max window width: 90% of screen width
        let maxWidth = screenFrame.width * 0.90
        
        // Max window height: 90% of screen height
        // Subtract UI chrome to get max image height
        let maxWindowHeight = screenFrame.height * 0.90
        let uiChromeHeight: CGFloat = 60 + 40 + 36 + 32 + 24 + 36  // prompt(3 lines) + buttons + toolbar + padding + spacing
        let maxHeight = maxWindowHeight - uiChromeHeight
        
        writeLog("VC: Screen=\(screenFrame.width)x\(screenFrame.height), maxWidth=\(maxWidth), maxHeight=\(maxHeight)")
        
        return (max(maxWidth, 400), max(maxHeight, 300))
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 12  // macOS system window style
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Image container with subtle background to distinguish from input area
        // Round only top corners (left-bottom/right-bottom are square)
        imageContainerView.wantsLayer = true
        imageContainerView.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
        imageContainerView.layer?.cornerRadius = 12
        // CALayer coordinate: MinY=bottom, MaxY=top. We want top corners only (left-top + right-top)
        imageContainerView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        imageContainerView.layer?.masksToBounds = true

        // Create a wrapper view for shadow (shadow and masksToBounds conflict)
        let shadowWrapper = NSView()
        shadowWrapper.wantsLayer = true
        shadowWrapper.layer?.shadowColor = NSColor.black.cgColor
        shadowWrapper.layer?.shadowOpacity = 0.15
        shadowWrapper.layer?.shadowOffset = CGSize(width: 0, height: -2)
        shadowWrapper.layer?.shadowRadius = 8
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false

        // Image view with 8px rounded corners (all 4 corners)
        // NSImageView's draw() bypasses layer masks, so use layer.contents directly
        imageWrapper.wantsLayer = true
        imageWrapper.layer?.masksToBounds = true
        imageWrapper.layer?.cornerRadius = 8  // Direct cornerRadius on layer
        // Match background color with imageContainerView so .resizeAspect gaps blend in
        imageWrapper.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
        imageWrapper.translatesAutoresizingMaskIntoConstraints = false
        
        // Set image directly to layer.contents (bypasses NSImageView draw issues)
        let cgImage = session.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        if let cgImage = cgImage {
            imageWrapper.layer?.contents = cgImage
            // .resizeAspect maintains aspect ratio; gaps now match background color
            imageWrapper.layer?.contentsGravity = .resizeAspect
        }
        
        // Keep imageView hidden but in hierarchy for compatibility
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageWrapper.addSubview(imageView)
        
        // Annotation canvas overlays the image
        annotationCanvasView.translatesAutoresizingMaskIntoConstraints = false
        annotationCanvasView.imageSize = session.image.size
        annotationCanvasView.delegate = self
        imageWrapper.addSubview(annotationCanvasView)

        // Hierarchy: imageContainerView > shadowWrapper > imageWrapper > imageView + annotationCanvasView
        shadowWrapper.addSubview(imageWrapper)
        imageContainerView.addSubview(shadowWrapper)
        
        // Annotation toolbar setup (inside image container, transparent background)
        annotationToolbar.translatesAutoresizingMaskIntoConstraints = false
        annotationToolbar.delegate = self
        annotationToolbar.layer?.backgroundColor = NSColor.clear.cgColor

        // Configure text view for editing
        promptTextView.isRichText = false
        promptTextView.allowsUndo = true
        promptTextView.isEditable = true
        promptTextView.isSelectable = true
        promptTextView.font = NSFont.systemFont(ofSize: 13)
        promptTextView.textColor = .labelColor
        promptTextView.backgroundColor = .clear
        promptTextView.delegate = self
        promptTextView.textContainerInset = NSSize(width: 8, height: 8)
        promptTextView.isVerticallyResizable = true
        promptTextView.isHorizontallyResizable = false
        promptTextView.autoresizingMask = [.width]
        promptTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        promptTextView.textContainer?.widthTracksTextView = true
        promptTextView.onCommandEnter = { [weak self] in
            self?.onCommandEnter?()
        }
        promptTextView.onTypingStarted = { [weak self] in
            // Hide placeholder immediately when typing starts
            self?.placeholderLabel.isHidden = true
        }

        // Configure scroll view
        promptScrollView.drawsBackground = true
        promptScrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.8)
        promptScrollView.borderType = .noBorder
        promptScrollView.hasVerticalScroller = true
        promptScrollView.autohidesScrollers = true
        promptScrollView.documentView = promptTextView
        promptScrollView.wantsLayer = true
        promptScrollView.layer?.cornerRadius = 10
        
        // Set the text view frame to match scroll view's content size
        let contentSize = promptScrollView.contentSize
        promptTextView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
        promptTextView.minSize = NSSize(width: 0, height: contentSize.height)
        promptTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        updatePlaceholderText()
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 13)
        placeholderLabel.maximumNumberOfLines = 1
        
        // Make placeholder click-through so clicks reach the text view behind it
        // Add click gesture to focus text view when placeholder is clicked
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(placeholderClicked))
        placeholderLabel.addGestureRecognizer(clickGesture)

        // Setup Send button (main button) with brand color styling
        sendButton.bezelStyle = .rounded
        sendButton.controlSize = .large
        sendButton.target = self
        sendButton.action = #selector(sendPressed)
        updateSendButtonTitle()
        updateSendButtonState()

        // Setup Dropdown button (arrow) - hover to show menu, click as fallback
        dropdownButton.bezelStyle = .rounded
        dropdownButton.controlSize = .large
        dropdownButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Select app")
        dropdownButton.imagePosition = .imageOnly
        dropdownButton.setContentHuggingPriority(.required, for: .horizontal)
        dropdownButton.target = self
        dropdownButton.action = #selector(dropdownClicked)
        
        // Create a container for the split button
        let splitButtonContainer = NSStackView(views: [sendButton, dropdownButton])
        splitButtonContainer.orientation = .horizontal
        splitButtonContainer.spacing = 8
        splitButtonContainer.distribution = .fill

        // Setup Close button
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .large
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        
        // ESC hint label (next to Close button)
        escHintLabel.textColor = .tertiaryLabelColor
        escHintLabel.font = NSFont.systemFont(ofSize: 11)

        let sendHint = NSTextField(labelWithString: "⌘↩︎ to Send")
        sendHint.textColor = .tertiaryLabelColor
        sendHint.font = NSFont.systemFont(ofSize: 11)

        // Layout: [Close] [ESC hint] [spacer] [send hint] [Split Button]
        let buttonsRow = NSStackView(views: [closeButton, escHintLabel, NSView(), sendHint, splitButtonContainer])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 10

        // Add views directly to main view (no NSStackView wrapper for precise control)
        view.addSubview(imageContainerView)
        view.addSubview(promptScrollView)
        view.addSubview(buttonsRow)
        view.addSubview(placeholderLabel)
        
        // Add toolbar inside image container (at the bottom)
        imageContainerView.addSubview(annotationToolbar)

        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        promptScrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Image area: no padding (top/left/right) - flush with Modal edges
            // Height includes: 16px top padding + image + 12px gap + 36px toolbar + 8px bottom padding
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            imageContainerView.heightAnchor.constraint(equalToConstant: imageDisplayHeight + 16 + 12 + 36 + 8),
            
            // Shadow wrapper inside container (above toolbar)
            shadowWrapper.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 16),
            shadowWrapper.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -16),
            shadowWrapper.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 16),
            shadowWrapper.heightAnchor.constraint(equalToConstant: imageDisplayHeight),
            
            // Image wrapper fills shadow wrapper
            imageWrapper.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            imageWrapper.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            imageWrapper.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            imageWrapper.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor),
            
            // Image fills image wrapper
            imageView.leadingAnchor.constraint(equalTo: imageWrapper.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageWrapper.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: imageWrapper.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageWrapper.bottomAnchor),
            
            // Annotation canvas fills image wrapper
            annotationCanvasView.leadingAnchor.constraint(equalTo: imageWrapper.leadingAnchor),
            annotationCanvasView.trailingAnchor.constraint(equalTo: imageWrapper.trailingAnchor),
            annotationCanvasView.topAnchor.constraint(equalTo: imageWrapper.topAnchor),
            annotationCanvasView.bottomAnchor.constraint(equalTo: imageWrapper.bottomAnchor),
            
            // Annotation toolbar at bottom of image container
            annotationToolbar.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 8),
            annotationToolbar.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -8),
            annotationToolbar.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: -8),
            annotationToolbar.heightAnchor.constraint(equalToConstant: 36),
            
            // Prompt input area (direct constraints, no stack wrapper)
            promptScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            promptScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            promptScrollView.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 12),
            promptScrollView.heightAnchor.constraint(equalToConstant: 60),  // ~3 lines
            
            // Buttons row (direct constraints)
            buttonsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonsRow.topAnchor.constraint(equalTo: promptScrollView.bottomAnchor, constant: 16),
            buttonsRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            // Placeholder label inside prompt area
            // Match textContainerInset (8) + textContainer lineFragmentPadding (5) = 13
            placeholderLabel.leadingAnchor.constraint(equalTo: promptScrollView.leadingAnchor, constant: 13),
            placeholderLabel.topAnchor.constraint(equalTo: promptScrollView.topAnchor, constant: 8),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: promptScrollView.trailingAnchor, constant: -13),
        ])

        updatePlaceholderVisibility()
    }

    var promptText: String {
        promptTextView.string
    }
    
    /// Get the currently selected target app
    var currentTargetApp: TargetApp? {
        selectedTargetApp
    }

    func focusPrompt() {
        let beforeResponder = view.window?.firstResponder
        view.window?.makeFirstResponder(promptTextView)
        let afterResponder = view.window?.firstResponder
        print("[CaptureModalVC] focusPrompt - before: \(String(describing: beforeResponder)), after: \(String(describing: afterResponder))")
        print("[CaptureModalVC] focusPrompt - promptScrollView.frame: \(promptScrollView.frame), contentSize: \(promptScrollView.contentSize)")
        print("[CaptureModalVC] focusPrompt - promptTextView.frame: \(promptTextView.frame), isEditable: \(promptTextView.isEditable)")
        print("[CaptureModalVC] focusPrompt - promptTextView.acceptsFirstResponder: \(promptTextView.acceptsFirstResponder)")
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        print("[CaptureModalVC] viewDidLayout - promptScrollView.frame: \(promptScrollView.frame), contentSize: \(promptScrollView.contentSize)")
        print("[CaptureModalVC] viewDidLayout - promptTextView.frame: \(promptTextView.frame)")
        
        // Ensure text view frame matches scroll view content size after layout
        let contentSize = promptScrollView.contentSize
        if promptTextView.frame.width != contentSize.width {
            promptTextView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: max(contentSize.height, promptTextView.frame.height))
            print("[CaptureModalVC] viewDidLayout - updated promptTextView.frame to: \(promptTextView.frame)")
        }
    }

    // MARK: - Button Actions

    @objc private func sendPressed() {
        if canSendToApp, let targetApp = selectedTargetApp {
            // Send to target app (optimized or generic)
            onPaste?(promptTextView.string, targetApp)
        } else {
            // Fallback to save when no target app or app is blacklisted
            onSave?()
        }
    }
    
    @objc private func closePressed() {
        onClose?()
    }
    
    // MARK: - Dropdown Click
    
    @objc private func dropdownClicked() {
        showAppSelectionMenu()
    }
    
    @objc private func placeholderClicked() {
        view.window?.makeFirstResponder(promptTextView)
    }

    // MARK: - App Selection Menu

    private func showAppSelectionMenu() {
        let menu = NSMenu()
        
        // Get running whitelisted apps
        let runningApps = AppDetectionService.shared.getRunningWhitelistedApps()
        
        if runningApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "No supported apps running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            menu.addItem(noAppsItem)
        } else {
            for app in runningApps {
                // Use "Send to AppName" format and send directly on click
                let item = NSMenuItem(title: "Send to \(app.displayName)", action: #selector(appMenuItemClicked(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = app
                if let icon = app.icon {
                    let resizedIcon = resizeImage(icon, to: NSSize(width: 16, height: 16))
                    item.image = resizedIcon
                }
                menu.addItem(item)
            }
        }
        
        // Add separator and Save option
        menu.addItem(.separator())
        
        let saveItem = NSMenuItem(title: "Save Image", action: #selector(saveMenuItemClicked), keyEquivalent: "")
        saveItem.target = self
        if let saveIcon = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save") {
            saveIcon.size = NSSize(width: 16, height: 16)
            saveItem.image = saveIcon
        }
        menu.addItem(saveItem)
        
        // Position the menu below the dropdown button
        let buttonFrame = dropdownButton.convert(dropdownButton.bounds, to: nil)
        let windowFrame = view.window?.convertToScreen(buttonFrame) ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: windowFrame.origin.x, y: windowFrame.origin.y), in: nil)
    }
    
    @objc private func saveMenuItemClicked() {
        onSave?()
    }
    
    @objc private func appMenuItemClicked(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? TargetApp else { return }
        // Directly send to the selected app
        onPaste?(promptTextView.string, app)
    }
    
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

    // MARK: - UI Updates

    private func updateSendButtonTitle() {
        let title: String
        if canSendToApp, let app = selectedTargetApp {
            title = "Send to \(app.displayName)"
        } else {
            // Show "Save Image" when no target app or app is blacklisted
            title = "Save Image"
        }
        sendButton.title = title
        
        // Re-apply styling after title change (button is always enabled now)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        sendButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
    
    private func updateSendButtonState() {
        // Button is always enabled - either sends to app or saves image
        sendButton.isEnabled = true
        
        // Apply brand color styling
        sendButton.bezelStyle = .rounded
        sendButton.isBordered = true
        sendButton.bezelColor = brandColor
        
        // Set white text using attributed title
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        sendButton.attributedTitle = NSAttributedString(string: sendButton.title, attributes: attributes)
        sendButton.toolTip = nil
    }
    
    private func updatePlaceholderText() {
        placeholderLabel.stringValue = "Add instructions (optional)"
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
    }

    private func updatePlaceholderVisibility() {
        let trimmed = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        placeholderLabel.isHidden = !trimmed.isEmpty
    }
    
    // MARK: - Annotation Access
    
    /// Get all annotations for rendering
    var annotations: [any Annotation] {
        annotationCanvasView.getAnnotations()
    }
    
    /// Delete the currently selected annotation
    func deleteSelectedAnnotation() {
        annotationCanvasView.deleteSelected()
    }
    
    /// Cancel in-progress annotation creation
    func cancelAnnotationCreation() {
        annotationCanvasView.cancelCreation()
    }
    
    // MARK: - AnnotationToolbarViewDelegate
    
    func toolbarDidSelectTool(_ tool: AnnotationTool) {
        annotationCanvasView.currentTool = tool
    }
    
    func toolbarDidSelectColor(_ color: AnnotationColor) {
        annotationCanvasView.currentColor = color
    }
    
    func toolbarDidPressClearAll() {
        annotationCanvasView.clearAll()
    }
    
    // MARK: - AnnotationCanvasViewDelegate
    
    func annotationCanvasDidChangeAnnotations(_ canvas: AnnotationCanvasView) {
        annotationToolbar.hasAnnotations = canvas.hasAnnotations
    }
}



