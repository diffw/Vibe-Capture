import AppKit

final class CaptureModalViewController: NSViewController, NSTextViewDelegate {
    var onClose: (() -> Void)?
    var onCopy: ((String) -> Void)?
    var onCommandEnter: (() -> Void)?

    private let session: CaptureSession
    private let imageDisplayHeight: CGFloat

    private let imageView = NSImageView()
    private let promptScrollView = NSScrollView()
    private let promptTextView = PromptTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "Paste to Cursor", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)

    init(session: CaptureSession) {
        self.session = session
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

        imageView.image = session.image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true

        promptTextView.isRichText = false
        promptTextView.allowsUndo = true
        promptTextView.font = NSFont.systemFont(ofSize: 13)
        promptTextView.textColor = .labelColor
        promptTextView.backgroundColor = .clear
        promptTextView.delegate = self
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

        placeholderLabel.stringValue = "Describe what should be changed.\nCursor will see both the image and this text."
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 13)
        placeholderLabel.maximumNumberOfLines = 2
        placeholderLabel.lineBreakMode = .byWordWrapping

        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .large
        copyButton.target = self
        copyButton.action = #selector(copyPressed)

        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closePressed)

        let hint = NSTextField(labelWithString: "⌘↩︎ to Paste")
        hint.textColor = .tertiaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 11)

        let buttonsRow = NSStackView(views: [closeButton, NSView(), hint, copyButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.alignment = .centerY
        buttonsRow.spacing = 10

        let stack = NSStackView(views: [imageView, promptScrollView, buttonsRow])
        stack.orientation = .vertical
        stack.spacing = 12

        view.addSubview(stack)
        view.addSubview(placeholderLabel)

        stack.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            imageView.heightAnchor.constraint(equalToConstant: imageDisplayHeight),
            promptScrollView.heightAnchor.constraint(equalToConstant: 140),

            placeholderLabel.leadingAnchor.constraint(equalTo: promptScrollView.leadingAnchor, constant: 12),
            placeholderLabel.topAnchor.constraint(equalTo: promptScrollView.topAnchor, constant: 10),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: promptScrollView.trailingAnchor, constant: -12),
        ])

        updatePlaceholderVisibility()
    }

    var promptText: String {
        promptTextView.string
    }

    func focusPrompt() {
        view.window?.makeFirstResponder(promptTextView)
    }

    @objc private func copyPressed() {
        onCopy?(promptTextView.string)
    }

    @objc private func closePressed() {
        onClose?()
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
    }

    private func updatePlaceholderVisibility() {
        let trimmed = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        placeholderLabel.isHidden = !trimmed.isEmpty
    }
}



