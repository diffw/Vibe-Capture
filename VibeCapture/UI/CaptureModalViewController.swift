import AppKit

final class CaptureModalViewController: NSViewController, NSTextViewDelegate {
    var onClose: (() -> Void)?
    var onPaste: ((String, TargetApp) -> Void)?
    var onSave: (() -> Void)?
    var onCommandEnter: (() -> Void)?

    private let session: CaptureSession
    private let imageDisplayHeight: CGFloat

    private let imageContainerView = NSView()
    private let imageView = NSImageView()
    private let promptScrollView = NSScrollView()
    private let promptTextView = PromptTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    
    // Split button for Paste
    private let pasteButton = NSButton(title: "Paste to App", target: nil, action: nil)
    private let dropdownButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    
    /// Currently selected target app
    private var selectedTargetApp: TargetApp?
    
    /// Whether the paste button should be enabled
    private var isPasteEnabled: Bool {
        guard let app = selectedTargetApp else { return false }
        return AppDetectionService.shared.isWhitelisted(app)
    }

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
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Image container with subtle background to distinguish from input area
        imageContainerView.wantsLayer = true
        imageContainerView.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
        imageContainerView.layer?.cornerRadius = 12

        // Image view with elegant shadow for visibility on white backgrounds
        imageView.image = session.image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        imageView.shadow = NSShadow()
        imageView.layer?.shadowColor = NSColor.black.cgColor
        imageView.layer?.shadowOpacity = 0.15
        imageView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        imageView.layer?.shadowRadius = 8

        // Add imageView inside container
        imageContainerView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        promptTextView.isRichText = false
        promptTextView.allowsUndo = true
        promptTextView.font = NSFont.systemFont(ofSize: 13)
        promptTextView.textColor = .labelColor
        promptTextView.backgroundColor = .clear
        promptTextView.delegate = self
        promptTextView.textContainerInset = NSSize(width: 8, height: 8)
        promptTextView.onCommandEnter = { [weak self] in
            self?.onCommandEnter?()
        }

        promptScrollView.drawsBackground = true
        promptScrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.8)
        promptScrollView.borderType = .noBorder
        promptScrollView.hasVerticalScroller = true
        promptScrollView.documentView = promptTextView
        promptScrollView.wantsLayer = true
        promptScrollView.layer?.cornerRadius = 10

        updatePlaceholderText()
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 13)
        placeholderLabel.maximumNumberOfLines = 2
        placeholderLabel.lineBreakMode = .byWordWrapping

        // Setup Paste button (main button)
        pasteButton.bezelStyle = .rounded
        pasteButton.controlSize = .large
        pasteButton.target = self
        pasteButton.action = #selector(pastePressed)
        updatePasteButtonTitle()
        updatePasteButtonState()

        // Setup Dropdown button (arrow)
        dropdownButton.bezelStyle = .rounded
        dropdownButton.controlSize = .large
        dropdownButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Select app")
        dropdownButton.imagePosition = .imageOnly
        dropdownButton.target = self
        dropdownButton.action = #selector(dropdownPressed)
        dropdownButton.setContentHuggingPriority(.required, for: .horizontal)
        
        // Create a container for the split button
        let splitButtonContainer = NSStackView(views: [pasteButton, dropdownButton])
        splitButtonContainer.orientation = .horizontal
        splitButtonContainer.spacing = 1
        splitButtonContainer.distribution = .fill

        // Setup Save button
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .large
        saveButton.target = self
        saveButton.action = #selector(savePressed)

        // Setup Close button
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closePressed)

        let hint = NSTextField(labelWithString: "⌘↩︎ to Paste")
        hint.textColor = .tertiaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)

        // Layout: [Close] [spacer] [hint] [Split Button] [Save]
        let buttonsRow = NSStackView(views: [closeButton, NSView(), hint, splitButtonContainer, saveButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 10

        let stack = NSStackView(views: [imageContainerView, promptScrollView, buttonsRow])
        stack.orientation = .vertical
        stack.spacing = 12

        view.addSubview(stack)
        view.addSubview(placeholderLabel)

        stack.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        let containerPadding: CGFloat = 12

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            // Container height = image height + padding
            imageContainerView.heightAnchor.constraint(equalToConstant: imageDisplayHeight + containerPadding * 2),

            // Image inside container with padding
            imageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: containerPadding),
            imageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -containerPadding),
            imageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: containerPadding),
            imageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: -containerPadding),

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

    @objc private func pastePressed() {
        guard let targetApp = selectedTargetApp, isPasteEnabled else { return }
        onPaste?(promptTextView.string, targetApp)
    }
    
    @objc private func savePressed() {
        onSave?()
    }

    @objc private func closePressed() {
        onClose?()
    }
    
    @objc private func dropdownPressed() {
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
                let item = NSMenuItem(title: app.displayName, action: #selector(appMenuItemSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = app
                if let icon = app.icon {
                    let resizedIcon = resizeImage(icon, to: NSSize(width: 16, height: 16))
                    item.image = resizedIcon
                }
                // Mark current selection
                if let selected = selectedTargetApp, selected.bundleIdentifier == app.bundleIdentifier {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }
        
        // Position the menu below the dropdown button
        let buttonFrame = dropdownButton.convert(dropdownButton.bounds, to: nil)
        let windowFrame = view.window?.convertToScreen(buttonFrame) ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: windowFrame.origin.x, y: windowFrame.origin.y), in: nil)
    }
    
    @objc private func appMenuItemSelected(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? TargetApp else { return }
        selectedTargetApp = app
        updatePasteButtonTitle()
        updatePasteButtonState()
        updatePlaceholderText()
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

    private func updatePasteButtonTitle() {
        if let app = selectedTargetApp {
            pasteButton.title = "Paste to \(app.displayName)"
        } else {
            pasteButton.title = "Paste"
        }
    }
    
    private func updatePasteButtonState() {
        pasteButton.isEnabled = isPasteEnabled
        
        // Update tooltip for disabled state
        if !isPasteEnabled {
            if let app = selectedTargetApp {
                pasteButton.toolTip = "\(app.displayName) is not a supported app"
            } else {
                pasteButton.toolTip = "No target app detected"
            }
        } else {
            pasteButton.toolTip = nil
        }
    }
    
    private func updatePlaceholderText() {
        if let app = selectedTargetApp {
            placeholderLabel.stringValue = "Describe what should be changed.\n\(app.displayName) will see both the image and this text."
        } else {
            placeholderLabel.stringValue = "Describe what should be changed.\nThe target app will see both the image and this text."
        }
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
    }

    private func updatePlaceholderVisibility() {
        let trimmed = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        placeholderLabel.isHidden = !trimmed.isEmpty
    }
}



