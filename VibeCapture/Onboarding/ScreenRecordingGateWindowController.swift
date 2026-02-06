import AppKit
import CoreGraphics

final class ScreenRecordingGateWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ScreenRecordingGateWindowController()

    private let vc = ScreenRecordingGateViewController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L("onboarding.window_title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .white
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 600, height: 640)
        window.contentMaxSize = NSSize(width: 600, height: 640)
        window.center()
        window.contentViewController = vc
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Use system window controls; only show Close.
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 24
            contentView.layer?.masksToBounds = true
            contentView.layer?.backgroundColor = NSColor.white.cgColor
        }

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        AppLog.log(.info, "permissions", "ScreenRecordingGateWindowController.show invoked")
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                AppLog.log(.error, "permissions", "ScreenRecordingGateWindowController.show: self or window is nil")
                return
            }
            self.vc.refreshStatus()
            
            // Ensure window has correct size before centering
            let targetSize = NSSize(width: 600, height: 640)
            window.setContentSize(targetSize)
            
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
            let frame = window.frame
            let screen = window.screen?.frame ?? .zero
            AppLog.log(.info, "permissions", "ScreenRecordingGateWindowController.show displayed window_visible=\(window.isVisible) frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height))) screen=(\(Int(screen.origin.x)),\(Int(screen.origin.y)) \(Int(screen.width))x\(Int(screen.height))) isOnActiveSpace=\(window.isOnActiveSpace) alphaValue=\(window.alphaValue)")
        }
    }

    func windowWillClose(_ notification: Notification) {
        // no-op
    }
}

private final class ScreenRecordingGateViewController: NSViewController {
    private let logoImageView = NSImageView()
    private let titleLabel = NSTextField(wrappingLabelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let screenshotView = GateScreenshotCardView()

    private let allowButton = OnboardingPillButton()
    private let skipButton = NSButton(title: "", target: nil, action: nil)

    private var pollTimer: Timer?

    // Use same colors as OnboardingFigma for consistency
    private static let primaryColor = NSColor(srgbRed: 115.0 / 255.0, green: 69.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) // #73452E

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.image = GateFigma.image(named: "logo", ext: "svg")

        titleLabel.maximumNumberOfLines = 0
        GateFigma.configureLabel(titleLabel)
        titleLabel.attributedStringValue = GateFigma.attributedText(
            string: L("onboarding.02.title"),
            font: NSFont.systemFont(ofSize: 24, weight: .bold),
            color: Self.primaryColor,
            lineHeightMultiple: 1.0
        )

        bodyLabel.maximumNumberOfLines = 0
        GateFigma.configureLabel(bodyLabel)
        bodyLabel.attributedStringValue = GateFigma.attributedBodyWithBoldTailInline(
            regular: L("onboarding.02.body"),
            bold: L("onboarding.02.body.bold"),
            fontSize: 16,
            color: Self.primaryColor,
            lineHeightMultiple: 1.2
        )

        screenshotView.configure(assetName: "system-settings")

        allowButton.title = L("onboarding.02.cta.allow")
        allowButton.target = self
        allowButton.action = #selector(allowPressed)
        allowButton.fillColor = Self.primaryColor
        allowButton.titleColor = .white
        allowButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        allowButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        allowButton.cornerRadius = 1000
        allowButton.imagePosition = .noImage
        allowButton.setButtonType(.momentaryPushIn)

        skipButton.title = L("onboarding.cta.skip")
        skipButton.target = self
        skipButton.action = #selector(skipPressed)
        GateFigma.applyLinkStyle(to: skipButton, color: Self.primaryColor, font: NSFont.systemFont(ofSize: 14, weight: .regular))

        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(screenshotView)
        view.addSubview(allowButton)
        view.addSubview(skipButton)

        for v in [logoImageView, titleLabel, bodyLabel, screenshotView, allowButton, skipButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        // Use same layout as OnboardingPermissionStepView (contentTop=80)
        let contentTop: CGFloat = 80
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: contentTop),
            logoImageView.widthAnchor.constraint(equalToConstant: 157),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: contentTop + 68),
            titleLabel.widthAnchor.constraint(equalToConstant: 416),

            bodyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72),
            bodyLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: contentTop + 106),
            bodyLabel.widthAnchor.constraint(equalToConstant: 416),

            screenshotView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72),
            screenshotView.topAnchor.constraint(equalTo: view.topAnchor, constant: contentTop + 190),
            screenshotView.widthAnchor.constraint(equalToConstant: 416),
            screenshotView.heightAnchor.constraint(equalToConstant: 228),

            allowButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72),
            allowButton.topAnchor.constraint(equalTo: view.topAnchor, constant: contentTop + 450),
            allowButton.widthAnchor.constraint(equalToConstant: 179),
            allowButton.heightAnchor.constraint(equalToConstant: 48),

            skipButton.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: 72 + 416),
            skipButton.centerYAnchor.constraint(equalTo: allowButton.centerYAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPolling()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshStatus()
        startPolling()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopPolling()
    }

    func refreshStatus() {}

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        let granted = CGPreflightScreenCaptureAccess()
        if granted {
            // Close automatically once user grants permission.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.view.window?.close()
            }
        }
    }

    @objc private func appBecameActive() {
        tick()
    }

    @objc private func allowPressed() {
        AppLog.log(.info, "permissions", "Gate allowPressed preflight=\(CGPreflightScreenCaptureAccess())")
        // Let System Settings be clickable (don't stay above it).
        view.window?.level = .normal
        view.window?.orderBack(nil)
        // Open System Settings directly; do NOT trigger CGRequestScreenCaptureAccess (no system dialog).
        PermissionsUI.openScreenRecordingSettings()
        tick()
    }

    @objc private func skipPressed() {
        view.window?.close()
    }
}

private enum GateFigma {
    static let blue = NSColor(srgbRed: 36.0 / 255.0, green: 76.0 / 255.0, blue: 100.0 / 255.0, alpha: 1.0) // #244C64
    static let gray666 = NSColor(srgbRed: 102.0 / 255.0, green: 102.0 / 255.0, blue: 102.0 / 255.0, alpha: 1.0) // #666666

    static func image(named assetName: String, ext: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext) {
            return SVGImageFallback.image(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Resources/Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
        }
        return nil
    }

    static func configureLabel(_ label: NSTextField) {
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
        lineHeightMultiple: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    static func attributedBodyWithBoldTailInline(
        regular: String,
        bold: String,
        fontSize: CGFloat,
        color: NSColor,
        lineHeightMultiple: CGFloat
    ) -> NSAttributedString {
        // Same line (no newline before bold) to match onboarding style
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

private final class GateScreenshotCardView: NSView {
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
        imageView.image = GateFigma.image(named: assetName, ext: "png")
    }
}

