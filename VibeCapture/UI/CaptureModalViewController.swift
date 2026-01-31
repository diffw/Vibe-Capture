import AppKit

final class CaptureModalViewController: NSViewController, NSTextViewDelegate, AnnotationToolbarViewDelegate, AnnotationCanvasViewDelegate {
    var onClose: (() -> Void)?
    var onSave: (() -> Void)?

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
    
    private let saveButton = RoundedHoverButton(title: "", target: nil, action: nil)
    private let copyButton = RoundedHoverButton(title: "", target: nil, action: nil)
    private let closeButton = RoundedHoverButton(title: "", target: nil, action: nil)
    private let copyPromptButton = RoundedHoverButton(title: "", target: nil, action: nil)
    private let escHintLabel = NSTextField(labelWithString: "")
    private let saveHintLabel = NSTextField(labelWithString: "⌘S to save")
    private let copyHintLabel = NSTextField(labelWithString: "")
    private let saveStack = NSStackView()
    private let copyStack = NSStackView()
    private let copyPromptStack = NSStackView()
    
    // Accessibility hint banner (for basic mode)
    private let accessibilityHintView = NSView()
    private let accessibilityHintLabel = NSTextField(labelWithString: "")
    private let accessibilityHintCTA = NSTextField(labelWithString: "")
    
    // Bottom constraints for dynamic layout
    private var buttonsRowBottomConstraint: NSLayoutConstraint?
    private var hintViewBottomConstraint: NSLayoutConstraint?
    
    // Basic mode: avoid spamming folder configuration hint
    private var didShowConfigureSaveFolderHint = false

    // Hover-to-reveal shortcut hints (labels above buttons)
    private let hintHoverDelaySeconds: TimeInterval = 0.25
    private var hintWorkItems: [String: DispatchWorkItem] = [:]

    // MARK: - Permission UX
    //
    // When opening System Settings for Accessibility, our capture modal (floating window)
    // can cover System Settings and block the user from granting permission. We temporarily
    // demote the window level so System Settings is usable, then restore when the app becomes active.
    private var didDemoteWindowForAccessibilityFlow = false
    private var previousWindowLevel: NSWindow.Level?
    private var didBecomeActiveObserver: NSObjectProtocol?
    
    /// Whether we have Accessibility permission for auto-paste
    private var hasAccessibilityPermission: Bool {
        ClipboardAutoPasteService.shared.hasAccessibilityPermission
    }
    
    /// Brand color for active send button
    private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76

    init(session: CaptureSession) {
        self.session = session
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

        return height
    }
    
    /// Calculate max dimensions based on screen size (mirrors WindowController logic)
    private static func calculateMaxDimensions() -> (maxWidth: CGFloat, maxHeight: CGFloat) {
        guard let screen = NSScreen.main else {
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
        
        return (max(maxWidth, 400), max(maxHeight, 300))
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView()
        view.setAccessibilityIdentifier("captureModal.root")
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
        promptTextView.onTypingStarted = { [weak self] in
            // Hide placeholder immediately when typing starts
            self?.placeholderLabel.isHidden = true
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoreWindowLevelAfterPermissionFlowIfNeeded()
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

        // Setup Save button
        saveButton.target = self
        saveButton.action = #selector(saveMenuItemClicked)
        saveButton.imagePosition = .imageLeading
        saveButton.imageScaling = .scaleProportionallyDown
        saveButton.imageHugsTitle = true
        saveButton.imageTitleSpacing = 8
        saveButton.fixedHeight = 32
        saveButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        // Setup Copy button (Copy & Arm)
        copyButton.target = self
        copyButton.action = #selector(copyPressed)
        copyButton.imagePosition = .imageLeading
        copyButton.imageScaling = .scaleProportionallyDown
        copyButton.imageHugsTitle = true
        copyButton.imageTitleSpacing = 8
        copyButton.fixedHeight = 32
        copyButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        copyButton.toolTip = "Copy & Arm (next ⌘V)"

        // Setup Close button
        closeButton.title = L("modal.button.close")
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.imagePosition = .imageLeading
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.imageHugsTitle = true
        closeButton.imageTitleSpacing = 8
        closeButton.fixedHeight = 32
        closeButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        
        // Setup Copy Prompt button (only shown in basic mode when there's prompt text)
        copyPromptButton.title = L("modal.button.copy_prompt")
        copyPromptButton.target = self
        copyPromptButton.action = #selector(copyPromptPressed)
        copyPromptButton.imagePosition = .imageLeading
        copyPromptButton.imageScaling = .scaleProportionallyDown
        copyPromptButton.imageHugsTitle = true
        copyPromptButton.imageTitleSpacing = 8
        copyPromptButton.fixedHeight = 32
        copyPromptButton.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        
        // Setup Accessibility hint banner
        setupAccessibilityHintBanner()

        // Shortcut hint labels (above buttons)
        escHintLabel.stringValue = L("modal.hint.esc_to_close")
        escHintLabel.textColor = .secondaryLabelColor
        escHintLabel.font = NSFont.systemFont(ofSize: 11)
        saveHintLabel.textColor = .secondaryLabelColor
        saveHintLabel.font = NSFont.systemFont(ofSize: 11)
        copyHintLabel.textColor = .secondaryLabelColor
        copyHintLabel.font = NSFont.systemFont(ofSize: 11)
        
        // Default hidden (reserve layout to avoid jumping)
        escHintLabel.alphaValue = 0
        saveHintLabel.alphaValue = 0
        copyHintLabel.alphaValue = 0

        // Copy hint label (text only; visibility is hover-driven)
        copyHintLabel.stringValue = "⌘C to Copy"
        let closeStack = NSStackView(views: [escHintLabel, closeButton])
        closeStack.orientation = .vertical
        closeStack.alignment = .leading
        closeStack.spacing = 4

        saveStack.orientation = .vertical
        saveStack.alignment = .centerX
        saveStack.spacing = 4
        saveStack.addArrangedSubview(saveHintLabel)
        saveStack.addArrangedSubview(saveButton)

        copyStack.orientation = .vertical
        copyStack.alignment = .centerX
        copyStack.spacing = 4
        copyStack.addArrangedSubview(copyHintLabel)
        copyStack.addArrangedSubview(copyButton)
        copyStack.isHidden = false
        
        // Copy Prompt stack (only visible in basic mode with prompt text)
        let copyPromptHintLabel = NSTextField(labelWithString: "")
        copyPromptHintLabel.textColor = .secondaryLabelColor
        copyPromptHintLabel.font = NSFont.systemFont(ofSize: 11)
        copyPromptStack.orientation = .vertical
        copyPromptStack.alignment = .centerX
        copyPromptStack.spacing = 4
        copyPromptStack.addArrangedSubview(copyPromptHintLabel)
        copyPromptStack.addArrangedSubview(copyPromptButton)
        copyPromptStack.isHidden = true  // Hidden by default

        // Layout: [Close stack] [spacer] [Save stack] [Copy stack] [Copy Prompt stack]
        let buttonsRow = NSStackView(views: [closeStack, NSView(), saveStack, copyStack, copyPromptStack])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .bottom
        buttonsRow.spacing = 12

        // Add views directly to main view (no NSStackView wrapper for precise control)
        view.addSubview(imageContainerView)
        view.addSubview(promptScrollView)
        view.addSubview(accessibilityHintView)
        view.addSubview(buttonsRow)
        view.addSubview(placeholderLabel)
        
        accessibilityHintView.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Buttons row (after prompt)
            buttonsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonsRow.topAnchor.constraint(equalTo: promptScrollView.bottomAnchor, constant: 12),
            
            // Accessibility hint banner (below buttons, only in basic mode)
            accessibilityHintView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            accessibilityHintView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            accessibilityHintView.topAnchor.constraint(equalTo: buttonsRow.bottomAnchor, constant: 12),

            // Placeholder label inside prompt area
            // Match textContainerInset (8) + textContainer lineFragmentPadding (5) = 13
            placeholderLabel.leadingAnchor.constraint(equalTo: promptScrollView.leadingAnchor, constant: 13),
            placeholderLabel.topAnchor.constraint(equalTo: promptScrollView.topAnchor, constant: 8),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: promptScrollView.trailingAnchor, constant: -13),
        ])
        
        // Dynamic bottom constraints (only one active at a time based on hint visibility)
        buttonsRowBottomConstraint = buttonsRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        hintViewBottomConstraint = accessibilityHintView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        updateBottomConstraints()

        updatePlaceholderVisibility()
        updateSendButtonTitle()
        updateButtonStyles()

        // Hover tracking to reveal hints (with slight delay)
        addHintTracking(to: closeButton, key: "close")
        addHintTracking(to: saveButton, key: "save")
        addHintTracking(to: copyButton, key: "copy")
    }

    deinit {
        for item in hintWorkItems.values { item.cancel() }
        hintWorkItems.removeAll()

        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }
    }

    var promptText: String {
        promptTextView.string
    }
    
    func focusPrompt() {
        let beforeResponder = view.window?.firstResponder
        view.window?.makeFirstResponder(promptTextView)
        let afterResponder = view.window?.firstResponder
#if DEBUG
        AppLog.log(.debug, "CaptureModal", "focusPrompt before=\(String(describing: beforeResponder)) after=\(String(describing: afterResponder))")
        AppLog.log(.debug, "CaptureModal", "focusPrompt scrollFrame=\(promptScrollView.frame) contentSize=\(promptScrollView.contentSize)")
        AppLog.log(.debug, "CaptureModal", "focusPrompt textFrame=\(promptTextView.frame) isEditable=\(promptTextView.isEditable) acceptsFirstResponder=\(promptTextView.acceptsFirstResponder)")
#endif
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
#if DEBUG
        AppLog.log(.debug, "CaptureModal", "viewDidLayout scrollFrame=\(promptScrollView.frame) contentSize=\(promptScrollView.contentSize)")
        AppLog.log(.debug, "CaptureModal", "viewDidLayout textFrame=\(promptTextView.frame)")
#endif
        
        // Ensure text view frame matches scroll view content size after layout
        let contentSize = promptScrollView.contentSize
        if promptTextView.frame.width != contentSize.width {
            promptTextView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: max(contentSize.height, promptTextView.frame.height))
#if DEBUG
            AppLog.log(.debug, "CaptureModal", "viewDidLayout updated textFrame=\(promptTextView.frame)")
#endif
        }
    }

    // MARK: - Accessibility Hint Banner Setup
    
    private func setupAccessibilityHintBanner() {
        accessibilityHintView.wantsLayer = true
        accessibilityHintView.layer?.backgroundColor = NSColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0).cgColor  // Light orange tint
        accessibilityHintView.layer?.cornerRadius = 8
        accessibilityHintView.layer?.borderWidth = 1
        accessibilityHintView.layer?.borderColor = brandColor.withAlphaComponent(0.3).cgColor
        
        // Make entire banner clickable
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(enableAutoSendPressed))
        accessibilityHintView.addGestureRecognizer(clickGesture)
        
        // Add hover cursor
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["view": "accessibilityHint"]
        )
        accessibilityHintView.addTrackingArea(trackingArea)
        
        // Icon
        let iconView = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        iconView.contentTintColor = brandColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Label - will be updated dynamically with app name
        accessibilityHintLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        accessibilityHintLabel.textColor = .labelColor
        accessibilityHintLabel.lineBreakMode = .byTruncatingTail
        accessibilityHintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // "Enable →" CTA text (pure text; entire banner is clickable via gesture)
        accessibilityHintCTA.stringValue = L("modal.button.enable_accessibility")
        accessibilityHintCTA.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        accessibilityHintCTA.textColor = .labelColor  // Same as label text
        accessibilityHintCTA.lineBreakMode = .byTruncatingTail
        accessibilityHintCTA.translatesAutoresizingMaskIntoConstraints = false
        
        accessibilityHintView.addSubview(iconView)
        accessibilityHintView.addSubview(accessibilityHintLabel)
        accessibilityHintView.addSubview(accessibilityHintCTA)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: accessibilityHintView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: accessibilityHintView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            accessibilityHintLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            accessibilityHintLabel.centerYAnchor.constraint(equalTo: accessibilityHintView.centerYAnchor),
            
            accessibilityHintCTA.leadingAnchor.constraint(greaterThanOrEqualTo: accessibilityHintLabel.trailingAnchor, constant: 8),
            accessibilityHintCTA.trailingAnchor.constraint(equalTo: accessibilityHintView.trailingAnchor, constant: -12),
            accessibilityHintCTA.centerYAnchor.constraint(equalTo: accessibilityHintView.centerYAnchor),
            
            accessibilityHintView.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        // Initially hidden if we have permission
        accessibilityHintView.isHidden = hasAccessibilityPermission
    }
    
    // Handle hover for accessibility hint banner
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String] else { return }
        if userInfo["view"] == "accessibilityHint" {
            NSCursor.pointingHand.push()
            return
        }
        if let hint = userInfo["hint"] {
            scheduleShowHint(for: hint)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String] else { return }
        if userInfo["view"] == "accessibilityHint" {
            NSCursor.pop()
            return
        }
        if let hint = userInfo["hint"] {
            cancelShowHint(for: hint)
            hideHint(for: hint)
        }
    }

    private func addHintTracking(to view: NSView, key: String) {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["hint": key]
        )
        view.addTrackingArea(area)
    }

    private func label(for hint: String) -> NSTextField? {
        switch hint {
        case "close": return escHintLabel
        case "save": return saveHintLabel
        case "copy": return copyHintLabel
        default: return nil
        }
    }

    private func scheduleShowHint(for hint: String) {
        cancelShowHint(for: hint)
        let item = DispatchWorkItem { [weak self] in
            self?.showHint(for: hint)
        }
        hintWorkItems[hint] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hintHoverDelaySeconds, execute: item)
    }

    private func cancelShowHint(for hint: String) {
        hintWorkItems[hint]?.cancel()
        hintWorkItems[hint] = nil
    }

    private func showHint(for hint: String) {
        guard let label = label(for: hint) else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            label.animator().alphaValue = 1
        }
    }

    private func hideHint(for hint: String) {
        guard let label = label(for: hint) else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            ctx.allowsImplicitAnimation = true
            label.animator().alphaValue = 0
        }
    }
    
    @objc private func enableAutoSendPressed() {
        // Step aside so System Settings isn't covered by our floating window.
        if let window = view.window {
            if previousWindowLevel == nil {
                previousWindowLevel = window.level
            }
            didDemoteWindowForAccessibilityFlow = true
            window.level = .normal
            window.orderBack(nil)
        }

        ClipboardAutoPasteService.shared.requestAccessibilityPermission()
        // Open System Settings
        PermissionsUI.openAccessibilitySettings()
    }

    private func restoreWindowLevelAfterPermissionFlowIfNeeded() {
        guard didDemoteWindowForAccessibilityFlow else { return }
        guard let window = view.window else { return }

        window.level = previousWindowLevel ?? .floating
        // Bring the capture modal back when the user returns to the app.
        window.makeKeyAndOrderFront(nil)

        didDemoteWindowForAccessibilityFlow = false
        previousWindowLevel = nil
    }
    
    private func updateBottomConstraints() {
        // When hint is hidden, buttonsRow is at bottom; when shown, hintView is at bottom
        let hintHidden = hasAccessibilityPermission
        buttonsRowBottomConstraint?.isActive = hintHidden
        hintViewBottomConstraint?.isActive = !hintHidden
    }

    // MARK: - Button Actions

    @objc private func copyPromptPressed() {
        let prompt = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([prompt as NSString])
        
        HUDService.shared.show(message: L("hud.prompt_copied"), style: .success, duration: 1.0)
    }
    
    /// Copy action shared by button + keyboard shortcut.
    /// - Parameter forceCloseAfterCopy: when true, always closes the modal if a copy happened.
    /// - Returns: true if we copied/armed successfully; false if blocked (e.g. needs permission).
    @discardableResult
    func performCopyAction(forceCloseAfterCopy: Bool) -> Bool {
        // Render image with annotations
        let finalImage = AnnotationRenderService.render(
            image: session.image,
            annotations: annotations
        )

        let prompt = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic mode: copy rules unchanged (always copy image only)
        guard hasAccessibilityPermission else {
            copyImageToClipboard()
            onClose?()
            return true
        }

        // Full mode:
        // - No prompt => Copy Image
        // - With prompt => Copy Image & Prompt (Copy & Arm)
        guard !prompt.isEmpty else {
            copyImageToClipboard()
            onClose?()
            return true
        }

        ClipboardAutoPasteService.shared.prepare(text: prompt, images: [finalImage])
        ClipboardAutoPasteService.shared.arm()
        HUDService.shared.show(message: L("hud.image_prompt_copied"), style: .success, duration: 1.0)
        onClose?()
        return true
    }

    private func copyImageToClipboard() {
        // Render image with annotations
        let finalImage = AnnotationRenderService.render(
            image: session.image,
            annotations: annotations
        )
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([finalImage])
        
        HUDService.shared.show(message: L("hud.image_copied"), style: .success, duration: 1.0)
        
        let hasPromptText = !promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // Auto-save (never prompts / never triggers preview on Copy)
        if SettingsStore.shared.saveEnabled {
            if let folderURL = ScreenshotSaveService.shared.currentFolderURL() {
                if let cgImage = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    DispatchQueue.global(qos: .utility).async {
                        do {
                            _ = try ScreenshotSaveService.shared.saveToKnownFolderAndReturnURL(cgImage: cgImage, folderURL: folderURL)
                        } catch {
                            AppLog.log(.error, "Capture", "Auto-save failed: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.2)
                            }
                        }
                    }
                } else {
                    AppLog.log(.error, "Capture", "Auto-save skipped: failed to extract CGImage")
                    HUDService.shared.show(message: L("error.image_encoding_failed"), style: .error, duration: 1.2)
                }
            } else if !didShowConfigureSaveFolderHint {
                didShowConfigureSaveFolderHint = true
                HUDService.shared.show(
                    message: L("hud.configure_save_folder", L("modal.button.save_image")),
                    style: .info,
                    duration: 2.0
                )
            }
        }
        
        // Close behavior: keep open if user has prompt (so they can copy prompt next)
        if !hasPromptText {
            onClose?()
        }
    }

    @objc private func copyPressed() {
        // Button behavior: copy then close modal.
        performCopyAction(forceCloseAfterCopy: true)
    }
    
    @objc private func closePressed() {
        onClose?()
    }
    
    @objc private func placeholderClicked() {
        view.window?.makeFirstResponder(promptTextView)
    }
    
    @objc private func saveMenuItemClicked() {
        onSave?()
    }

    private func makeTemplateIcon(named name: String, size: CGFloat, fallbackSystemName: String? = nil) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            if let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: size, height: size)
                image.isTemplate = true
                AppLog.log(.debug, "icons", "Loaded SVG icon \(name) via NSImage(contentsOf:)")
                return image
            }

            AppLog.log(.warn, "icons", "Failed to decode SVG icon \(name) at \(url.lastPathComponent)")
        }
        if let fallbackSystemName {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            AppLog.log(.debug, "icons", "Using SF Symbol fallback for \(name): \(fallbackSystemName)")
            return NSImage(systemSymbolName: fallbackSystemName, accessibilityDescription: name)?
                .withSymbolConfiguration(config)
        }
        return nil
    }

    // MARK: - UI Updates

    private func updateSendButtonTitle() {
        closeButton.image = makeTemplateIcon(named: "close-line", size: 12, fallbackSystemName: "xmark")
        saveButton.image = makeTemplateIcon(named: "download-line", size: 14, fallbackSystemName: "square.and.arrow.down")
        copyButton.image = makeTemplateIcon(named: "file-copy-line", size: 14, fallbackSystemName: "doc.on.doc")
        copyPromptButton.image = makeTemplateIcon(named: "file-copy-line", size: 14, fallbackSystemName: "doc.on.doc")

        closeButton.title = L("modal.button.close")
        saveButton.title = L("modal.button.save_image")
        escHintLabel.stringValue = L("modal.hint.esc_to_close")

        let hasPromptText = !promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasAccessibilityPermission {
            copyButton.title = hasPromptText ? L("modal.button.copy_image_and_prompt") : L("modal.button.copy_image")
        } else {
            // Basic mode: keep copy rules unchanged (copy image only)
            copyButton.title = L("modal.button.copy_image")
        }
        copyHintLabel.stringValue = "⌘C to Copy"

        // Basic mode: allow copying prompt separately
        copyPromptButton.title = L("modal.button.copy_prompt")
        copyPromptStack.isHidden = hasAccessibilityPermission || !hasPromptText
        copyStack.isHidden = false

        // Banner copy
        accessibilityHintView.isHidden = hasAccessibilityPermission
        updateBottomConstraints()
        if !hasAccessibilityPermission {
            accessibilityHintLabel.stringValue = L("modal.hint.enable_copy_image_prompt")
            accessibilityHintCTA.stringValue = L("modal.button.enable_accessibility")
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

        closeButton.style = closeStyle
        saveButton.style = secondary
        copyButton.style = primary
        copyPromptButton.style = primary
        
        saveButton.isEnabled = true
        copyButton.isEnabled = true
        closeButton.isEnabled = true
        copyPromptButton.isEnabled = true
    }
    
    private func updatePlaceholderText() {
        placeholderLabel.stringValue = L("modal.placeholder.add_instructions")
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
        // Update UI to show/hide Copy Prompt button based on prompt text
        updateSendButtonTitle()
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



