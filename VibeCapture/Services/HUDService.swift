import AppKit

final class HUDService {
    static let shared = HUDService()

    enum Style {
        case success
        case error
        case info
    }

    private var window: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(message: String, style: Style = .info, duration: TimeInterval = 0.85) {
        DispatchQueue.main.async {
            self.dismissWorkItem?.cancel()

            let view = HUDView(message: message, style: style)
            let size = view.fittingSize

            let window: NSWindow
            if let existing = self.window {
                window = existing
            } else {
                window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: max(220, size.width), height: size.height),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                // CRITICAL: Prevent double-release in Swift/ARC.
                window.isReleasedWhenClosed = false
            }

            window.contentView = view
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true

            if let screen = NSScreen.main {
                let origin = CGPoint(
                    x: screen.frame.midX - window.frame.width / 2,
                    y: screen.frame.midY - window.frame.height / 2
                )
                window.setFrameOrigin(origin)
            } else {
                window.center()
            }

            window.alphaValue = 1.0
            window.orderFrontRegardless()
            self.window = window

            let workItem = DispatchWorkItem { [weak self] in
                self?.fadeOutAndClose()
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }

    private func fadeOutAndClose() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
}

private final class HUDView: NSView {
    private let message: String
    private let style: HUDService.Style

    private let effectView = NSVisualEffectView()
    private let label = NSTextField(labelWithString: "")

    init(message: String, style: HUDService.Style) {
        self.message = message
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true

        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12

        label.stringValue = message
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = colorForStyle()
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping

        addSubview(effectView)
        effectView.addSubview(label)

        effectView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -10),
        ])
    }

    private func colorForStyle() -> NSColor {
        switch style {
        case .success: return NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // Brand color #FF8D76
        case .error: return NSColor.systemRed
        case .info: return NSColor.labelColor
        }
    }
}



