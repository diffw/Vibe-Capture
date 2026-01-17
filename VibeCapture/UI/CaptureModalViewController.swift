import AppKit

final class CaptureModalViewController: NSViewController, NSTextViewDelegate {
    var onClose: (() -> Void)?
    var onPaste: ((String, TargetApp) -> Void)?
    var onSave: (() -> Void)?
    var onCommandEnter: (() -> Void)?

    private let session: CaptureSession
    private let imageDisplayHeight: CGFloat

    private let imageContainerView = NSView()
    private let imageWrapper = NSView()  // Wrapper for rounded corners mask
    private let imageView = NSImageView()
    private let promptScrollView = NSScrollView()
    private let promptTextView = PromptTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    
    // Split button for Send
    private let sendButton = NSButton(title: "Send to App", target: nil, action: nil)
    private let dropdownButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let escHintLabel = NSTextField(labelWithString: "ESC to close")
    
    /// Currently selected target app
    private var selectedTargetApp: TargetApp?
    
    /// Whether the send button should be enabled
    private var isSendEnabled: Bool {
        guard let app = selectedTargetApp else { return false }
        return AppDetectionService.shared.isWhitelisted(app)
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

        let maxHeight: CGFloat = 400
        let minWidth: CGFloat = 400 - 32 // minWindowWidth - padding
        let maxWidth: CGFloat = 800 - 32 // maxWindowWidth - padding

        let aspectRatio = imageSize.width / imageSize.height

        // Start with max height
        var height = min(imageSize.height, maxHeight)
        var width = height * aspectRatio

        // Adjust if width is out of bounds
        if width > maxWidth {
            width = maxWidth
            height = width / aspectRatio
        } else if width < minWidth {
            width = minWidth
            height = min(width / aspectRatio, maxHeight)
        }

        return height
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

        // Hierarchy: imageContainerView > shadowWrapper > imageWrapper > imageView
        shadowWrapper.addSubview(imageWrapper)
        imageContainerView.addSubview(shadowWrapper)

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
        splitButtonContainer.spacing = 1
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

        // Stack for prompt and buttons only (image is separate)
        let stack = NSStackView(views: [promptScrollView, buttonsRow])
        stack.orientation = .vertical
        stack.spacing = 16

        // Add views directly to main view
        view.addSubview(imageContainerView)
        view.addSubview(stack)
        view.addSubview(placeholderLabel)

        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Image area: no padding (top/left/right) - flush with Modal edges
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            imageContainerView.heightAnchor.constraint(equalToConstant: imageDisplayHeight + 32), // +16px padding top and bottom
            
            // Shadow wrapper inside container with 16px padding
            shadowWrapper.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 16),
            shadowWrapper.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -16),
            shadowWrapper.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 16),
            shadowWrapper.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: -16),
            
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
            
            // Stack for prompt and buttons with padding
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            promptScrollView.heightAnchor.constraint(equalToConstant: 140),

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
        view.window?.makeFirstResponder(promptTextView)
    }

    // MARK: - Button Actions

    @objc private func sendPressed() {
        guard let targetApp = selectedTargetApp, isSendEnabled else { return }
        onPaste?(promptTextView.string, targetApp)
    }
    
    @objc private func closePressed() {
        onClose?()
    }
    
    // MARK: - Dropdown Click
    
    @objc private func dropdownClicked() {
        showAppSelectionMenu()
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
        if let app = selectedTargetApp {
            title = "Send to \(app.displayName)"
        } else {
            title = "Send"
        }
        sendButton.title = title
        
        // Re-apply styling after title change
        if isSendEnabled {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
            sendButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        }
    }
    
    private func updateSendButtonState() {
        sendButton.isEnabled = isSendEnabled
        
        // Apply brand color styling when enabled
        if isSendEnabled {
            // Use a custom colored button appearance
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
        } else {
            // Reset to default styling
            sendButton.bezelStyle = .rounded
            sendButton.isBordered = true
            sendButton.bezelColor = nil
            sendButton.attributedTitle = NSAttributedString(string: sendButton.title)
            
            // Update tooltip for disabled state
            if let app = selectedTargetApp {
                sendButton.toolTip = "\(app.displayName) is not a supported app"
            } else {
                sendButton.toolTip = "No target app detected"
            }
        }
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
}



