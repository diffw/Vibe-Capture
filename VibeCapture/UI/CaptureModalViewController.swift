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
    private let sendButton = RoundedHoverButton(title: "Send to App", target: nil, action: nil)
    private let dropdownButton = RoundedHoverButton(title: "", target: nil, action: nil)
    private let saveButton = RoundedHoverButton(title: "Save Image", target: nil, action: nil)
    private let closeButton = RoundedHoverButton(title: "Close", target: nil, action: nil)
    private let escHintLabel = NSTextField(labelWithString: "ESC to close")
    private let saveHintLabel = NSTextField(labelWithString: "⌘S to save")
    private let sendHintLabel = NSTextField(labelWithString: "⌘↩︎ to send")
    private let saveStack = NSStackView()
    
    /// Currently selected target app
    private var selectedTargetApp: TargetApp?
    private var appActivationObserver: NSObjectProtocol?
    
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
    
    /// Whether we have a valid target app to send to (whitelisted + not blacklisted)
    private var canSendToApp: Bool {
        guard let app = selectedTargetApp else { return false }
        return AppDetectionService.shared.isWhitelisted(app) && !isAppBlacklisted
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

        // Setup Send button (main button)
        sendButton.target = self
        sendButton.action = #selector(sendPressed)
        sendButton.imagePosition = .imageLeading
        sendButton.imageScaling = .scaleProportionallyDown
        sendButton.imageHugsTitle = true
        sendButton.fixedHeight = 32
        sendButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        sendButton.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        updateSendButtonTitle()
        updateButtonStyles()

        // Setup Dropdown button (arrow)
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        dropdownButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Select app")?
            .withSymbolConfiguration(chevronConfig)
        dropdownButton.imagePosition = .imageOnly
        dropdownButton.fixedHeight = 32
        dropdownButton.contentInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        dropdownButton.setContentHuggingPriority(.required, for: .horizontal)
        dropdownButton.target = self
        dropdownButton.action = #selector(dropdownClicked)
        dropdownButton.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]

        // Setup Save button
        saveButton.target = self
        saveButton.action = #selector(saveMenuItemClicked)
        saveButton.imagePosition = .imageLeading
        saveButton.imageScaling = .scaleProportionallyDown
        saveButton.imageHugsTitle = true
        saveButton.fixedHeight = 32
        saveButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        // Create a container for the split button (Send + Dropdown)
        let splitButtonContainer = NSStackView(views: [sendButton, dropdownButton])
        splitButtonContainer.orientation = .horizontal
        splitButtonContainer.spacing = 1
        splitButtonContainer.distribution = .fill

        // Setup Close button
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.imagePosition = .imageLeading
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.imageHugsTitle = true
        closeButton.fixedHeight = 32
        closeButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        // Shortcut hint labels (above buttons)
        escHintLabel.textColor = .tertiaryLabelColor
        escHintLabel.font = NSFont.systemFont(ofSize: 11)
        saveHintLabel.textColor = .tertiaryLabelColor
        saveHintLabel.font = NSFont.systemFont(ofSize: 11)
        sendHintLabel.textColor = .tertiaryLabelColor
        sendHintLabel.font = NSFont.systemFont(ofSize: 11)

        let closeStack = NSStackView(views: [escHintLabel, closeButton])
        closeStack.orientation = .vertical
        closeStack.alignment = .leading
        closeStack.spacing = 4

        saveStack.orientation = .vertical
        saveStack.alignment = .centerX
        saveStack.spacing = 4
        saveStack.addArrangedSubview(saveHintLabel)
        saveStack.addArrangedSubview(saveButton)

        let sendStack = NSStackView(views: [sendHintLabel, splitButtonContainer])
        sendStack.orientation = .vertical
        sendStack.alignment = .centerX
        sendStack.spacing = 4

        // Layout: [Close stack] [spacer] [Save stack] [Send stack]
        let buttonsRow = NSStackView(views: [closeStack, NSView(), saveStack, sendStack])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .bottom
        buttonsRow.spacing = 12

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

            dropdownButton.widthAnchor.constraint(equalToConstant: 32),
            dropdownButton.heightAnchor.constraint(equalTo: sendButton.heightAnchor),

            // Placeholder label inside prompt area
            // Match textContainerInset (8) + textContainer lineFragmentPadding (5) = 13
            placeholderLabel.leadingAnchor.constraint(equalTo: promptScrollView.leadingAnchor, constant: 13),
            placeholderLabel.topAnchor.constraint(equalTo: promptScrollView.topAnchor, constant: 8),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: promptScrollView.trailingAnchor, constant: -13),
        ])

        updatePlaceholderVisibility()
        startAppActivationObserver()
    }

    deinit {
        stopAppActivationObserver()
    }

    var promptText: String {
        promptTextView.string
    }
    
    /// Get the currently selected target app
    var currentTargetApp: TargetApp? {
        selectedTargetApp
    }
    
    var canSendToCurrentTargetApp: Bool {
        canSendToApp
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

    private func startAppActivationObserver() {
        guard appActivationObserver == nil else { return }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTargetAppFromFrontmost()
        }
        updateTargetAppFromFrontmost()
    }

    private func stopAppActivationObserver() {
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
    }

    private func updateTargetAppFromFrontmost() {
        let targetApp = AppDetectionService.shared.getTargetApp()
        guard targetApp != selectedTargetApp else { return }
        selectedTargetApp = targetApp
        updateSendButtonTitle()
        updateButtonStyles()
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
        
        // Add separator and "Add to Send List..." option
        menu.addItem(.separator())
        
        let addAppItem = NSMenuItem(title: "Add to Send List...", action: #selector(addToSendListClicked), keyEquivalent: "")
        addAppItem.target = self
        if let addIcon = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add") {
            addIcon.size = NSSize(width: 16, height: 16)
            addAppItem.image = addIcon
        }
        menu.addItem(addAppItem)
        
        // Manual boundary detection for floating/borderless windows
        guard let window = dropdownButton.window,
              let screen = window.screen ?? NSScreen.main else {
            menu.popUp(positioning: nil, at: .zero, in: dropdownButton)
            return
        }
        
        let buttonFrame = dropdownButton.convert(dropdownButton.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)
        
        // Calculate available space below button
        let spaceBelow = screenFrame.minY - screen.visibleFrame.minY
        
        // Estimate menu height (~22pt per item, ~11pt per separator)
        let separatorCount = menu.items.filter { $0.isSeparatorItem }.count
        let regularItemCount = menu.items.count - separatorCount
        let estimatedMenuHeight = CGFloat(regularItemCount) * 22 + CGFloat(separatorCount) * 11
        
        if spaceBelow < estimatedMenuHeight {
            // Not enough space below → pop up above button
            menu.popUp(positioning: menu.items.last,
                       at: NSPoint(x: 0, y: dropdownButton.bounds.height),
                       in: dropdownButton)
        } else {
            // Normal: pop up below button
            menu.popUp(positioning: nil, at: .zero, in: dropdownButton)
        }
    }
    
    @objc private func addToSendListClicked() {
        guard let window = view.window else { return }
        let panelController = AddAppPanelController(onAppAdded: nil)
        panelController.showAsSheet(relativeTo: window)
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

    private func makeTemplateIcon(named name: String, size: CGFloat, fallbackSystemName: String? = nil) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: size, height: size)
            image.isTemplate = true
            return image
        }
        if let fallbackSystemName {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            return NSImage(systemSymbolName: fallbackSystemName, accessibilityDescription: name)?
                .withSymbolConfiguration(config)
        }
        return nil
    }

    // MARK: - UI Updates

    private func updateSendButtonTitle() {
        closeButton.image = makeTemplateIcon(named: "close-line", size: 12, fallbackSystemName: "xmark")
        saveButton.image = makeTemplateIcon(named: "download-line", size: 14, fallbackSystemName: "square.and.arrow.down")

        if canSendToApp, let app = selectedTargetApp {
            sendButton.title = "Send to \(app.displayName)"
            if let icon = app.icon {
                sendButton.image = resizeImage(icon, to: NSSize(width: 16, height: 16))
            } else {
                sendButton.image = nil
            }
            saveStack.isHidden = false
            sendHintLabel.stringValue = "⌘↩︎ to send"
        } else {
            // When no valid target app, primary action is Save Image
            sendButton.title = "Save Image"
            sendButton.image = makeTemplateIcon(named: "download-line", size: 14, fallbackSystemName: "square.and.arrow.down")
            saveStack.isHidden = true
            sendHintLabel.stringValue = "⌘S to save"
        }
    }
    
    private func updateButtonStyles() {
        let primary = RoundedHoverButton.Style(
            background: brandColor,
            hoverBackground: brandColor.blended(withFraction: 0.12, of: .white) ?? brandColor,
            pressedBackground: brandColor.blended(withFraction: 0.12, of: .black) ?? brandColor,
            borderColor: nil,
            borderWidth: 0,
            titleColor: .white
        )
        let secondary = RoundedHoverButton.Style(
            background: .white,
            hoverBackground: NSColor(white: 0.97, alpha: 1.0),
            pressedBackground: NSColor(white: 0.93, alpha: 1.0),
            borderColor: NSColor(calibratedWhite: 0.87, alpha: 1.0),
            borderWidth: 1,
            titleColor: .labelColor
        )
        let closeStyle = RoundedHoverButton.Style(
            background: NSColor(white: 0.93, alpha: 1.0),
            hoverBackground: NSColor(white: 0.88, alpha: 1.0),
            pressedBackground: NSColor(white: 0.84, alpha: 1.0),
            borderColor: nil,
            borderWidth: 0,
            titleColor: .labelColor
        )

        sendButton.style = primary
        dropdownButton.style = primary
        closeButton.style = closeStyle

        if canSendToApp {
            saveButton.style = secondary
        } else {
            saveButton.style = primary
        }
        sendButton.isEnabled = true
        dropdownButton.isEnabled = true
        saveButton.isEnabled = true
        closeButton.isEnabled = true
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



