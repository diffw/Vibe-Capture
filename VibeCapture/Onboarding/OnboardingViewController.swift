import AppKit
import ApplicationServices

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

/// A pill-shaped button that renders reliably without relying on layer styling.
final class OnboardingPillButton: NSButton {
    var fillColor: NSColor = .controlAccentColor { didSet { needsDisplay = true } }
    var pressedFillColor: NSColor? { didSet { needsDisplay = true } }
    var titleColor: NSColor = .white { didSet { needsDisplay = true } }
    var titleFont: NSFont = NSFont.systemFont(ofSize: 18, weight: .semibold) { didSet { needsDisplay = true } }

    var contentInsets: NSEdgeInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32) {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }
    var imageTitleSpacing: CGFloat = 12 {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }
    var cornerRadius: CGFloat = 1000 { didSet { needsDisplay = true } }
    var imageDrawSize: NSSize = NSSize(width: 24, height: 24) { didSet { needsDisplay = true } }

    private var isPressed = false

    override var title: String {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }

    override var image: NSImage? {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }

    override var isEnabled: Bool {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .none
        imageScaling = .scaleProportionallyDown
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        super.mouseDown(with: event)
        isPressed = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = min(cornerRadius, bounds.height / 2)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        let baseFill = fillColor
        let fill: NSColor = {
            if !isEnabled { return baseFill.withAlphaComponent(0.55) }
            if isPressed { return pressedFillColor ?? baseFill.blended(withFraction: 0.12, of: .black) ?? baseFill }
            return baseFill
        }()

        fill.setFill()
        path.fill()

        // Content rect (padding).
        let contentRect = NSRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.bottom,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttrs)
        let titleSize = titleString.size()

        let hasImage = (image != nil)
        let spacing = (hasImage && !title.isEmpty) ? imageTitleSpacing : 0
        let imageSize = hasImage ? imageDrawSize : .zero

        let totalWidth: CGFloat = {
            switch imagePosition {
            case .imageLeading:
                return imageSize.width + spacing + titleSize.width
            case .imageTrailing:
                return titleSize.width + spacing + imageSize.width
            default:
                return titleSize.width
            }
        }()

        var x = contentRect.minX + max(0, (contentRect.width - totalWidth) / 2)
        let centerY = contentRect.midY

        func drawImage(_ img: NSImage, at x: CGFloat) {
            let drawRect = NSRect(
                x: x,
                y: centerY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            let toDraw: NSImage
            if img.isTemplate {
                toDraw = img.tinted(with: titleColor)
            } else {
                toDraw = img
            }
            toDraw.draw(in: drawRect)
        }

        switch imagePosition {
        case .imageLeading:
            if let img = image {
                drawImage(img, at: x)
                x += imageSize.width + spacing
            }
            titleString.draw(at: NSPoint(x: x, y: centerY - titleSize.height / 2))
        case .imageTrailing:
            titleString.draw(at: NSPoint(x: x, y: centerY - titleSize.height / 2))
            x += titleSize.width + spacing
            if let img = image {
                drawImage(img, at: x)
            }
        default:
            titleString.draw(at: NSPoint(x: x, y: centerY - titleSize.height / 2))
        }
    }
}

/// A field-chrome style button (white fill, border, subtle shadow).
final class OnboardingFieldButton: NSButton {
    var fillColor: NSColor = .white { didSet { needsDisplay = true } }
    var borderColor: NSColor = NSColor(srgbRed: 229.0 / 255.0, green: 231.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0) { didSet { needsDisplay = true } } // #E5E7EB
    var borderWidth: CGFloat = 1 { didSet { needsDisplay = true } }
    var cornerRadius: CGFloat = 10 { didSet { needsDisplay = true } }
    var titleColor: NSColor = NSColor(srgbRed: 115.0 / 255.0, green: 69.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) { didSet { needsDisplay = true } } // #73452E
    var titleFont: NSFont = NSFont.systemFont(ofSize: 12, weight: .medium) { didSet { needsDisplay = true } }

    private let shadow1: NSShadow = {
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.10)
        s.shadowBlurRadius = 3
        s.shadowOffset = CGSize(width: 0, height: -1) // down in AppKit coords
        return s
    }()

    override var title: String {
        didSet { needsDisplay = true }
    }

    override var isEnabled: Bool {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .none
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = min(cornerRadius, bounds.height / 2)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        shadow1.set()
        fillColor.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
        ]
        let titleString = NSAttributedString(string: title, attributes: attrs)
        let titleSize = titleString.size()
        titleString.draw(at: NSPoint(x: bounds.midX - titleSize.width / 2, y: bounds.midY - titleSize.height / 2))
    }
}

/// A field-chrome container (white fill, border, subtle shadow) that can host subviews.
class OnboardingFieldChromeView: NSView {
    var fillColor: NSColor = .white { didSet { needsDisplay = true } }
    var borderColor: NSColor = NSColor(srgbRed: 229.0 / 255.0, green: 231.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0) { didSet { needsDisplay = true } } // #E5E7EB
    var borderWidth: CGFloat = 1 { didSet { needsDisplay = true } }
    var cornerRadius: CGFloat = 10 { didSet { needsDisplay = true } }

    private let shadow1: NSShadow = {
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.10)
        s.shadowBlurRadius = 3
        s.shadowOffset = CGSize(width: 0, height: -1)
        return s
    }()

    override func draw(_ dirtyRect: NSRect) {
        let radius = min(cornerRadius, bounds.height / 2)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        shadow1.set()
        fillColor.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }
}

final class OnboardingViewController: NSViewController {
    private let store = OnboardingStore.shared

    private var currentStep: OnboardingStep = .welcome
    private var pollTimer: Timer?

    // MARK: - Figma step views

    private let welcomeView = OnboardingWelcomeStepView()
    private let screenRecordingView = OnboardingPermissionStepView(contentTop: 80, logoAssetName: "logo", showSkip: false)
    private let accessibilityView = OnboardingPermissionStepView(contentTop: 80, logoAssetName: "logo", showSkip: true)
    private let preferencesView = OnboardingPreferencesStepView()
    private let paywallView = OnboardingPaywallView()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor

        welcomeView.primaryButton.target = self
        welcomeView.primaryButton.action = #selector(primaryPressed)

        screenRecordingView.allowButton.target = self
        screenRecordingView.allowButton.action = #selector(primaryPressed)
        screenRecordingView.continueButton.target = self
        screenRecordingView.continueButton.action = #selector(continuePressed)
        screenRecordingView.skipButton.target = self
        screenRecordingView.skipButton.action = #selector(secondaryPressed)
        screenRecordingView.restartButton.target = self
        screenRecordingView.restartButton.action = #selector(restartPressed)

        accessibilityView.allowButton.target = self
        accessibilityView.allowButton.action = #selector(primaryPressed)
        accessibilityView.continueButton.target = self
        accessibilityView.continueButton.action = #selector(continuePressed)
        accessibilityView.skipButton.target = self
        accessibilityView.skipButton.action = #selector(secondaryPressed)
        accessibilityView.restartButton.target = self
        accessibilityView.restartButton.action = #selector(restartPressed)

        preferencesView.allowButton.target = self
        preferencesView.allowButton.action = #selector(primaryPressed)
        preferencesView.skipButton.target = self
        preferencesView.skipButton.action = #selector(secondaryPressed)
        preferencesView.onContinueValidationError = { [weak self] message in
            self?.showAlert(title: L("onboarding.error.title"), message: message)
        }

        paywallView.onFinished = { [weak self] in
            self?.store.markFlowCompleted()
            self?.view.window?.close()
        }

        for v in [welcomeView, screenRecordingView, accessibilityView, preferencesView, paywallView] {
            view.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                v.topAnchor.constraint(equalTo: view.topAnchor),
                v.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            v.isHidden = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self)
        stopPolling()
    }

    func start(at step: OnboardingStep) {
        // Normalize: if stored step is .done, restart at welcome (should be completed anyway).
        let normalized: OnboardingStep = (step == .done) ? .welcome : step
        go(to: normalized, persist: false)
    }

    // MARK: - Navigation

    private func go(to step: OnboardingStep, persist: Bool = true) {
        currentStep = step
        if persist {
            store.step = step
        }
        render()
    }

    private func advance() {
        go(to: currentStep.next)
    }

    private func render() {
        stopPolling()
        welcomeView.isHidden = true
        screenRecordingView.isHidden = true
        accessibilityView.isHidden = true
        preferencesView.isHidden = true
        paywallView.isHidden = true
        applyPreferredWindowSize()

        switch currentStep {
        case .welcome:
            welcomeView.isHidden = false
            welcomeView.configure(
                logoAssetName: "logo",
                headline: L("onboarding.01.title"),
                subheadline: L("onboarding.01.body"),
                body: L("onboarding.01.detail"),
                primaryTitle: L("onboarding.01.cta")
            )

        case .screenRecording:
            screenRecordingView.isHidden = false
            screenRecordingView.titleLabel.attributedStringValue = OnboardingFigma.attributedText(
                string: L("onboarding.02.title"),
                font: NSFont.systemFont(ofSize: 24, weight: .heavy),
                color: OnboardingFigma.primary,
                lineHeightMultiple: 1.1
            )
            screenRecordingView.bodyLabel.attributedStringValue = OnboardingFigma.attributedBodyWithBoldTailInline(
                regular: L("onboarding.02.body"),
                bold: L("onboarding.02.body.bold"),
                fontSize: 16,
                color: OnboardingFigma.primary,
                lineHeightMultiple: 1.5
            )
            screenRecordingView.allowButton.title = L("onboarding.02.cta.allow")
            screenRecordingView.restartButton.isHidden = true
            screenRecordingView.configureScreenshot(assetName: "system-settings")
            updateScreenRecordingStatusAndMaybeAdvance()
            startPolling()

        case .accessibility:
            accessibilityView.isHidden = false
            accessibilityView.titleLabel.attributedStringValue = OnboardingFigma.attributedText(
                string: L("onboarding.03.title"),
                font: NSFont.systemFont(ofSize: 24, weight: .heavy),
                color: OnboardingFigma.primary,
                lineHeightMultiple: 1.1
            )
            accessibilityView.bodyLabel.attributedStringValue = OnboardingFigma.attributedText(
                string: L("onboarding.03.body"),
                font: NSFont.systemFont(ofSize: 16, weight: .regular),
                color: OnboardingFigma.primary,
                lineHeightMultiple: 1.5
            )
            accessibilityView.allowButton.title = L("onboarding.03.cta.allow")
            accessibilityView.skipButton.title = L("onboarding.cta.skip")
            accessibilityView.restartButton.isHidden = true
            accessibilityView.configureScreenshot(assetName: "system-settings")
            updateAccessibilityStatusAndMaybeAdvance()
            startPolling()

        case .preferences:
            preferencesView.isHidden = false
            preferencesView.configure(
                logoAssetName: "logo",
                title: L("onboarding.04.title"),
                body: L("onboarding.04.body"),
                allowTitle: L("onboarding.04.cta.continue"),
                skipTitle: L("onboarding.cta.skip")
            )

        case .paywall:
            paywallView.isHidden = false

        case .done:
            store.markFlowCompleted()
            view.window?.close()
        }
    }

    // MARK: - Window sizing

    static func preferredContentSize(for step: OnboardingStep) -> NSSize {
        // Matches the Figma frames for onboarding01–05.
        switch step {
        case .welcome, .preferences:
            return NSSize(width: 560, height: 540)
        case .screenRecording, .accessibility:
            return NSSize(width: 560, height: 658)
        case .paywall:
            return NSSize(width: 560, height: 640)
        case .done:
            return NSSize(width: 560, height: 540)
        }
    }

    private func applyPreferredWindowSize() {
        guard let window = view.window else { return }
        let target = Self.preferredContentSize(for: currentStep)
        guard window.contentView?.frame.size != target else { return }

        window.contentMinSize = target
        window.contentMaxSize = target

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().setContentSize(target)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollTick() {
        switch currentStep {
        case .screenRecording:
            updateScreenRecordingStatusAndMaybeAdvance()
        case .accessibility:
            updateAccessibilityStatusAndMaybeAdvance()
        default:
            break
        }
    }

    @objc private func appBecameActive() {
        pollTick()
    }

    private func updateScreenRecordingStatusAndMaybeAdvance() {
        let granted = CGPreflightScreenCaptureAccess()
        screenRecordingView.setPermissionGranted(
            granted,
            allowTitle: L("onboarding.02.cta.allow"),
            grantedTitle: L("onboarding.cta.granted"),
            continueTitle: L("onboarding.cta.continue")
        )
    }

    private func updateAccessibilityStatusAndMaybeAdvance() {
        let granted = AXIsProcessTrusted()
        accessibilityView.setPermissionGranted(
            granted,
            allowTitle: L("onboarding.03.cta.allow"),
            grantedTitle: L("onboarding.cta.granted"),
            continueTitle: L("onboarding.cta.continue")
        )
    }

    // MARK: - Actions

    @objc private func primaryPressed() {
        switch currentStep {
        case .welcome:
            advance()
        case .screenRecording:
            // Let System Settings be clickable (don't stay above it).
            store.shouldResumeAfterRestart = true
            view.window?.orderBack(nil)
            PermissionsUI.openScreenRecordingSettings()
            pollTick()
        case .accessibility:
            ClipboardAutoPasteService.shared.requestAccessibilityPermission()
            // Let System Settings be clickable (don't stay above it).
            view.window?.orderBack(nil)
            PermissionsUI.openAccessibilitySettings()
            pollTick()
        case .preferences:
            // Validate preferences step (e.g. shortcut registration can fail) before moving on.
            if preferencesView.applyIfNeeded() {
                advance()
            }
        case .paywall:
            // Placeholder: proceed to done to avoid blocking.
            advance()
        case .done:
            break
        }
    }

    @objc private func secondaryPressed() {
        switch currentStep {
        case .screenRecording, .accessibility, .preferences:
            advance()
        case .welcome, .paywall, .done:
            break
        }
    }

    @objc private func continuePressed() {
        switch currentStep {
        case .screenRecording:
            guard CGPreflightScreenCaptureAccess() else { return }
            advance()
        case .accessibility:
            guard AXIsProcessTrusted() else { return }
            advance()
        case .welcome, .preferences, .paywall, .done:
            break
        }
    }

    @objc private func restartPressed() {
        store.step = currentStep
        store.shouldResumeAfterRestart = true
        AppRelauncher.restart()
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("button.ok"))
        alert.beginSheetModal(for: view.window ?? NSApp.keyWindow ?? NSWindow(), completionHandler: nil)
    }
}

// MARK: - Figma helpers / views

private enum OnboardingFigma {
    static let primary = NSColor(srgbRed: 115.0 / 255.0, green: 69.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) // #73452E
    static let secondary = NSColor(srgbRed: 139.0 / 255.0, green: 107.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0) // #8B6B5C
    static let border = NSColor(srgbRed: 229.0 / 255.0, green: 231.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0) // #E5E7EB
    static let pillBg = NSColor(srgbRed: 249.0 / 255.0, green: 250.0 / 255.0, blue: 251.0 / 255.0, alpha: 1.0) // #F9FAFB

    static func image(named assetName: String, ext: String) -> NSImage? {
        // Prefer structured subdirectory lookup (what Xcode typically preserves).
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
        }
        // Fallbacks: flat resources or folder-reference style bundles.
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext) {
            return SVGImageFallback.image(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Resources/Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
        }
        return nil
    }

    static func configureLabel(_ label: NSTextField) {
        // Prevent field-editor takeover (which can drop attributed styling) when clicked.
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.focusRingType = .none
    }

    static func attributedText(
        string: String,
        font: NSFont,
        color: NSColor,
        lineHeightMultiple: CGFloat,
        alignment: NSTextAlignment = .left,
        kern: CGFloat? = nil
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if let kern {
            attrs[.kern] = kern
        }
        return NSAttributedString(string: string, attributes: attrs)
    }

    static func attributedBodyWithBoldTail(
        regular: String,
        bold: String,
        fontSize: CGFloat,
        color: NSColor,
        lineHeightMultiple: CGFloat
    ) -> NSAttributedString {
        let full = regular + "\n" + bold
        let regularFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let out = NSMutableAttributedString(string: full, attributes: [
            .font: regularFont,
            .foregroundColor: color,
        ])

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))

        let boldRange = (full as NSString).range(of: bold)
        if boldRange.location != NSNotFound {
            out.addAttribute(.font, value: boldFont, range: boldRange)
        }
        return out
    }

    static func attributedBodyWithBoldTailInline(
        regular: String,
        bold: String,
        fontSize: CGFloat,
        color: NSColor,
        lineHeightMultiple: CGFloat
    ) -> NSAttributedString {
        let full = regular + " " + bold
        let regularFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let out = NSMutableAttributedString(string: full, attributes: [
            .font: regularFont,
            .foregroundColor: color,
        ])

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))

        let boldRange = (full as NSString).range(of: bold)
        if boldRange.location != NSNotFound {
            out.addAttribute(.font, value: boldFont, range: boldRange)
        }
        return out
    }

    static func applyLinkStyle(to button: NSButton, color: NSColor, font: NSFont) {
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = font
        button.contentTintColor = color
    }
}

private final class OnboardingWelcomeStepView: NSView {
    let logoImageView = NSImageView()
    let headlineLabel = NSTextField(wrappingLabelWithString: "")
    let subheadlineLabel = NSTextField(wrappingLabelWithString: "")
    let bodyLabel = NSTextField(wrappingLabelWithString: "")
    let primaryButton = OnboardingPillButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.imageAlignment = .alignLeft

        headlineLabel.maximumNumberOfLines = 0
        subheadlineLabel.maximumNumberOfLines = 0
        bodyLabel.maximumNumberOfLines = 0
        OnboardingFigma.configureLabel(headlineLabel)
        OnboardingFigma.configureLabel(subheadlineLabel)
        OnboardingFigma.configureLabel(bodyLabel)

        primaryButton.fillColor = OnboardingFigma.primary
        primaryButton.titleColor = .white
        primaryButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        primaryButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        primaryButton.imageTitleSpacing = 12
        primaryButton.cornerRadius = 1000
        primaryButton.imagePosition = .imageTrailing
        primaryButton.imageDrawSize = NSSize(width: 24, height: 24)
        primaryButton.setButtonType(.momentaryPushIn)

        addSubview(logoImageView)
        addSubview(headlineLabel)
        addSubview(subheadlineLabel)
        addSubview(bodyLabel)
        addSubview(primaryButton)

        for v in [logoImageView, headlineLabel, subheadlineLabel, bodyLabel, primaryButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 80),
            logoImageView.widthAnchor.constraint(equalToConstant: 157),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            headlineLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            headlineLabel.topAnchor.constraint(equalTo: topAnchor, constant: 148),
            headlineLabel.widthAnchor.constraint(equalToConstant: 416),

            subheadlineLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            subheadlineLabel.topAnchor.constraint(equalTo: topAnchor, constant: 284),
            subheadlineLabel.widthAnchor.constraint(equalToConstant: 416),

            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            bodyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 344),
            bodyLabel.widthAnchor.constraint(equalToConstant: 416),

            primaryButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            primaryButton.topAnchor.constraint(equalTo: topAnchor, constant: 410),
            primaryButton.widthAnchor.constraint(equalToConstant: 201),
            primaryButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    func configure(logoAssetName: String, headline: String, subheadline: String, body: String, primaryTitle: String) {
        logoImageView.image = OnboardingFigma.image(named: logoAssetName, ext: "svg")

        headlineLabel.attributedStringValue = OnboardingFigma.attributedText(
            string: headline,
            font: NSFont.systemFont(ofSize: 36, weight: .heavy),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 1.1
        )
        subheadlineLabel.attributedStringValue = OnboardingFigma.attributedText(
            string: subheadline,
            font: NSFont.systemFont(ofSize: 20, weight: .bold),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 1.1
        )
        bodyLabel.attributedStringValue = OnboardingFigma.attributedText(
            string: body,
            font: NSFont.systemFont(ofSize: 14, weight: .regular),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 1.2
        )

        primaryButton.title = primaryTitle
        primaryButton.image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)
        primaryButton.imagePosition = .imageTrailing
        primaryButton.imageScaling = .scaleProportionallyDown
        primaryButton.contentTintColor = .white
    }
}

private final class OnboardingPermissionStepView: NSView {
    let logoImageView = NSImageView()
    let titleLabel = NSTextField(wrappingLabelWithString: "")
    let bodyLabel = NSTextField(wrappingLabelWithString: "")
    let screenshotView = OnboardingScreenshotCardView()
    let allowButton = OnboardingPillButton()
    let continueButton = OnboardingPillButton()
    let restartButton = NSButton(title: "", target: nil, action: nil)
    let skipButton = NSButton(title: "", target: nil, action: nil)

    private let contentTop: CGFloat
    private let logoAssetName: String
    private let showSkip: Bool

    init(contentTop: CGFloat, logoAssetName: String, showSkip: Bool) {
        self.contentTop = contentTop
        self.logoAssetName = logoAssetName
        self.showSkip = showSkip
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.imageAlignment = .alignLeft
        logoImageView.image = OnboardingFigma.image(named: logoAssetName, ext: "svg")

        titleLabel.maximumNumberOfLines = 0
        bodyLabel.maximumNumberOfLines = 0
        OnboardingFigma.configureLabel(titleLabel)
        OnboardingFigma.configureLabel(bodyLabel)

        allowButton.fillColor = OnboardingFigma.primary
        allowButton.titleColor = .white
        allowButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        allowButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        allowButton.imagePosition = .noImage
        allowButton.setButtonType(.momentaryPushIn)

        continueButton.fillColor = OnboardingFigma.primary
        continueButton.titleColor = .white
        continueButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        continueButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        continueButton.imagePosition = .noImage
        continueButton.setButtonType(.momentaryPushIn)
        continueButton.isHidden = true

        restartButton.title = L("onboarding.cta.restart")
        OnboardingFigma.applyLinkStyle(
            to: restartButton,
            color: OnboardingFigma.primary,
            font: NSFont.systemFont(ofSize: 14, weight: .regular)
        )
        restartButton.isHidden = true

        OnboardingFigma.applyLinkStyle(to: skipButton, color: OnboardingFigma.primary, font: NSFont.systemFont(ofSize: 14, weight: .regular))
        skipButton.isHidden = !showSkip

        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(bodyLabel)
        addSubview(screenshotView)
        addSubview(allowButton)
        addSubview(continueButton)
        addSubview(restartButton)
        addSubview(skipButton)

        for v in [logoImageView, titleLabel, bodyLabel, screenshotView, allowButton, continueButton, restartButton, skipButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: contentTop),
            logoImageView.widthAnchor.constraint(equalToConstant: 157),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: contentTop + 68),
            titleLabel.widthAnchor.constraint(equalToConstant: 416),

            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            bodyLabel.topAnchor.constraint(equalTo: topAnchor, constant: contentTop + 106),
            bodyLabel.widthAnchor.constraint(equalToConstant: 416),

            screenshotView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            screenshotView.topAnchor.constraint(equalTo: topAnchor, constant: contentTop + 190),
            screenshotView.widthAnchor.constraint(equalToConstant: 416),
            screenshotView.heightAnchor.constraint(equalToConstant: 228),

            allowButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            allowButton.topAnchor.constraint(equalTo: topAnchor, constant: contentTop + 450),
            allowButton.widthAnchor.constraint(equalToConstant: 179),
            allowButton.heightAnchor.constraint(equalToConstant: 48),

            continueButton.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 72 + 416),
            continueButton.topAnchor.constraint(equalTo: allowButton.topAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 179),
            continueButton.heightAnchor.constraint(equalToConstant: 48),

            restartButton.leadingAnchor.constraint(equalTo: allowButton.leadingAnchor),
            restartButton.topAnchor.constraint(equalTo: allowButton.bottomAnchor, constant: 10),

            skipButton.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 72 + 416),
            skipButton.centerYAnchor.constraint(equalTo: allowButton.centerYAnchor),
        ])
    }

    func configureScreenshot(assetName: String) {
        screenshotView.configure(assetName: assetName)
    }

    func setPermissionGranted(_ granted: Bool, allowTitle: String, grantedTitle: String, continueTitle: String) {
        if granted {
            allowButton.title = grantedTitle
            allowButton.isEnabled = false
            allowButton.fillColor = NSColor.systemGreen

            continueButton.title = continueTitle
            continueButton.isHidden = false
            skipButton.isHidden = true
        } else {
            allowButton.title = allowTitle
            allowButton.isEnabled = true
            allowButton.fillColor = OnboardingFigma.primary

            continueButton.isHidden = true
            skipButton.isHidden = !showSkip
        }
    }
}

private final class OnboardingScreenshotCardView: NSView {
    private let shadowView = NSView()
    private let clipView = NSView()
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true

        shadowView.wantsLayer = true
        shadowView.layer?.cornerRadius = 16
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.18
        shadowView.layer?.shadowRadius = 10
        shadowView.layer?.shadowOffset = CGSize(width: 0, height: -4)

        clipView.wantsLayer = true
        clipView.layer?.cornerRadius = 16
        clipView.layer?.masksToBounds = true
        clipView.layer?.backgroundColor = NSColor.white.cgColor

        imageView.imageScaling = .scaleAxesIndependently

        addSubview(shadowView)
        shadowView.addSubview(clipView)
        clipView.addSubview(imageView)

        for v in [shadowView, clipView, imageView] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            shadowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shadowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            shadowView.topAnchor.constraint(equalTo: topAnchor),
            shadowView.bottomAnchor.constraint(equalTo: bottomAnchor),

            clipView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            clipView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            clipView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            clipView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            imageView.widthAnchor.constraint(equalToConstant: 1036),
            imageView.heightAnchor.constraint(equalToConstant: 670),
            imageView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: -225),
            imageView.topAnchor.constraint(equalTo: clipView.topAnchor, constant: -121),
        ])
    }

    func configure(assetName: String) {
        imageView.image = OnboardingFigma.image(named: assetName, ext: "png")
    }
}

private final class OnboardingPreferencesStepView: NSView {
    var onContinueValidationError: ((String) -> Void)?

    let logoImageView = NSImageView()
    let titleLabel = NSTextField(wrappingLabelWithString: "")
    let bodyLabel = NSTextField(wrappingLabelWithString: "")
    let allowButton = OnboardingPillButton()
    let skipButton = NSButton(title: "", target: nil, action: nil)

    private let saveTitle = NSTextField(labelWithString: "")
    private let saveField = OnboardingFieldChromeView()
    private let saveIcon = NSImageView()
    private let savePathLabel = NSTextField(labelWithString: "")
    private let browseButton = OnboardingFieldButton()

    private let shortcutTitle = NSTextField(labelWithString: "")
    private let shortcutRow = ShortcutRowControl()

    private var pendingShortcut: KeyCombo?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.imageAlignment = .alignLeft

        titleLabel.maximumNumberOfLines = 0
        bodyLabel.maximumNumberOfLines = 0
        OnboardingFigma.configureLabel(titleLabel)
        OnboardingFigma.configureLabel(bodyLabel)

        saveTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        saveTitle.textColor = OnboardingFigma.primary
        saveTitle.alignment = .left
        OnboardingFigma.configureLabel(saveTitle)

        shortcutTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        shortcutTitle.textColor = OnboardingFigma.primary
        shortcutTitle.alignment = .left
        OnboardingFigma.configureLabel(shortcutTitle)

        saveField.fillColor = .white
        saveField.borderColor = OnboardingFigma.border
        saveField.borderWidth = 1
        saveField.cornerRadius = 10

        saveIcon.imageScaling = .scaleProportionallyUpOrDown
        saveIcon.image = OnboardingFigma.image(named: "icon-folder", ext: "svg")

        savePathLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        savePathLabel.textColor = OnboardingFigma.primary.withAlphaComponent(0.90)
        savePathLabel.lineBreakMode = .byTruncatingMiddle
        OnboardingFigma.configureLabel(savePathLabel)

        browseButton.title = L("onboarding.04.browse")
        browseButton.target = self
        browseButton.action = #selector(browsePressed)
        browseButton.fillColor = .white
        browseButton.borderColor = OnboardingFigma.border
        browseButton.borderWidth = 1
        browseButton.cornerRadius = 10
        browseButton.titleFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        browseButton.titleColor = OnboardingFigma.primary
        browseButton.setButtonType(.momentaryPushIn)

        shortcutRow.onChange = { [weak self] combo in
            self?.pendingShortcut = combo
        }

        allowButton.fillColor = OnboardingFigma.primary
        allowButton.titleColor = .white
        allowButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        allowButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        allowButton.imagePosition = .noImage
        allowButton.setButtonType(.momentaryPushIn)
        OnboardingFigma.applyLinkStyle(to: skipButton, color: OnboardingFigma.primary, font: NSFont.systemFont(ofSize: 14, weight: .regular))

        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(bodyLabel)

        // Preferences controls
        addSubview(saveTitle)
        addSubview(saveField)
        saveField.addSubview(saveIcon)
        saveField.addSubview(savePathLabel)
        addSubview(browseButton)

        addSubview(shortcutTitle)
        addSubview(shortcutRow)

        // Bottom actions
        addSubview(allowButton)
        addSubview(skipButton)

        for v in [logoImageView, titleLabel, bodyLabel, saveTitle, saveField, saveIcon, savePathLabel, browseButton, shortcutTitle, shortcutRow, allowButton, skipButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        // Layout based on Figma metadata (560x540 root, content at x=72, y=80, width=416).
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 80),
            logoImageView.widthAnchor.constraint(equalToConstant: 157),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 148),
            titleLabel.widthAnchor.constraint(equalToConstant: 416),

            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            bodyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 186),
            bodyLabel.widthAnchor.constraint(equalToConstant: 416),

            // Save location label
            saveTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            saveTitle.topAnchor.constraint(equalTo: topAnchor, constant: 242),
            saveTitle.heightAnchor.constraint(equalToConstant: 14),

            // Save field + browse button row
            saveField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            saveField.topAnchor.constraint(equalTo: topAnchor, constant: 260),
            saveField.heightAnchor.constraint(equalToConstant: 34),
            saveField.widthAnchor.constraint(equalToConstant: 328.242),

            saveIcon.leadingAnchor.constraint(equalTo: saveField.leadingAnchor, constant: 13),
            saveIcon.centerYAnchor.constraint(equalTo: saveField.centerYAnchor),
            saveIcon.widthAnchor.constraint(equalToConstant: 16),
            saveIcon.heightAnchor.constraint(equalToConstant: 16),

            savePathLabel.leadingAnchor.constraint(equalTo: saveIcon.trailingAnchor, constant: 8),
            savePathLabel.centerYAnchor.constraint(equalTo: saveField.centerYAnchor),
            savePathLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveField.trailingAnchor, constant: -12),

            browseButton.leadingAnchor.constraint(equalTo: saveField.trailingAnchor, constant: 8),
            browseButton.centerYAnchor.constraint(equalTo: saveField.centerYAnchor),
            browseButton.widthAnchor.constraint(equalToConstant: 79.758),
            browseButton.heightAnchor.constraint(equalToConstant: 34),

            // Global shortcut
            shortcutTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            shortcutTitle.topAnchor.constraint(equalTo: topAnchor, constant: 318),
            shortcutTitle.heightAnchor.constraint(equalToConstant: 14),

            shortcutRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            shortcutRow.topAnchor.constraint(equalTo: topAnchor, constant: 336),
            shortcutRow.widthAnchor.constraint(equalToConstant: 416),
            shortcutRow.heightAnchor.constraint(equalToConstant: 44),

            // Bottom actions row
            allowButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            allowButton.topAnchor.constraint(equalTo: topAnchor, constant: 412),
            allowButton.widthAnchor.constraint(equalToConstant: 179),
            allowButton.heightAnchor.constraint(equalToConstant: 48),

            skipButton.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 72 + 416),
            skipButton.centerYAnchor.constraint(equalTo: allowButton.centerYAnchor),
        ])

        refreshSavePathLabel()
        refreshTypography()
    }

    func configure(logoAssetName: String, title: String, body: String, allowTitle: String, skipTitle: String) {
        logoImageView.image = OnboardingFigma.image(named: logoAssetName, ext: "svg")
        titleLabel.attributedStringValue = OnboardingFigma.attributedText(
            string: title,
            font: NSFont.systemFont(ofSize: 24, weight: .heavy),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 1.1
        )
        bodyLabel.attributedStringValue = OnboardingFigma.attributedText(
            string: body,
            font: NSFont.systemFont(ofSize: 16, weight: .regular),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 1.5
        )
        allowButton.title = allowTitle
        skipButton.title = skipTitle
    }

    private func refreshTypography() {
        saveTitle.attributedStringValue = OnboardingFigma.attributedText(
            string: L("onboarding.04.save_location").uppercased(),
            font: NSFont.systemFont(ofSize: 12, weight: .medium),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 16.0 / 12.0,
            kern: 0.6
        )
        shortcutTitle.attributedStringValue = OnboardingFigma.attributedText(
            string: L("onboarding.04.global_shortcut").uppercased(),
            font: NSFont.systemFont(ofSize: 12, weight: .medium),
            color: OnboardingFigma.primary,
            lineHeightMultiple: 16.0 / 12.0,
            kern: 0.6
        )
    }

    private func refreshSavePathLabel() {
        if let url = ScreenshotSaveService.shared.currentFolderURL() {
            savePathLabel.stringValue = url.path
        } else {
            // Prefill: ~/Desktop/Screenshots (matches Figma)
            savePathLabel.stringValue = "~/Desktop/Screenshots"
        }
    }

    @objc private func browsePressed() {
        do {
            _ = try ScreenshotSaveService.shared.chooseAndStoreFolder()
            refreshSavePathLabel()
        } catch {
            onContinueValidationError?(error.localizedDescription)
        }
    }

    /// Apply pending settings changes. Returns true if safe to proceed.
    func applyIfNeeded() -> Bool {
        if let combo = pendingShortcut {
            do {
                try ShortcutManager.shared.updateHotKey(combo)
            } catch {
                onContinueValidationError?(error.localizedDescription)
                return false
            }
        }
        return true
    }
}

private final class ShortcutRowControl: OnboardingFieldChromeView {
    var onChange: ((KeyCombo) -> Void)?

    private var currentCombo: KeyCombo = SettingsStore.shared.captureHotKey {
        didSet { updateUI() }
    }
    private var isRecording = false {
        didSet { updateUI() }
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pillView = NSView()
    private let pillLabel = NSTextField(labelWithString: "")

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        fillColor = .white
        borderColor = OnboardingFigma.border
        borderWidth = 1
        cornerRadius = 10

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = OnboardingFigma.image(named: "icon-shortcut", ext: "svg")

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = OnboardingFigma.primary
        titleLabel.stringValue = L("onboarding.04.shortcut_row_title")
        OnboardingFigma.configureLabel(titleLabel)

        pillView.wantsLayer = true
        pillView.layer?.backgroundColor = OnboardingFigma.pillBg.cgColor
        pillView.layer?.cornerRadius = 4
        pillView.layer?.borderWidth = 1
        pillView.layer?.borderColor = OnboardingFigma.border.cgColor

        pillLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        pillLabel.textColor = OnboardingFigma.secondary
        pillLabel.alignment = .center
        OnboardingFigma.configureLabel(pillLabel)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(pillView)
        pillView.addSubview(pillLabel)

        for v in [iconView, titleLabel, pillView, pillLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            pillView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            pillView.centerYAnchor.constraint(equalTo: centerYAnchor),
            pillView.widthAnchor.constraint(equalToConstant: 60),
            pillView.heightAnchor.constraint(equalToConstant: 26),

            pillLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 6),
            pillLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -6),
            pillLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
        ])

        updateUI()
    }

    private func updateUI() {
        if isRecording {
            pillLabel.stringValue = L("settings.shortcut.recording_short")
            pillLabel.textColor = OnboardingFigma.primary
        } else {
            pillLabel.stringValue = currentCombo.displayString
            pillLabel.textColor = OnboardingFigma.secondary
        }
    }

    override func mouseDown(with event: NSEvent) {
        isRecording.toggle()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Esc cancels
            isRecording = false
            return
        }

        let modifiers = event.modifierFlags.intersection(KeyCombo.allowedModifierFlags)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            HUDService.shared.show(message: L("error.modifier_required"), style: .error, duration: 1.0)
            return
        }

        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        currentCombo = combo
        isRecording = false
        onChange?(combo)
    }
}
