import AppKit

final class CountdownCloseButton: NSButton {
    var onTimeout: (() -> Void)?

    static let buttonSize: CGFloat = 22

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private var timer: Timer?
    private var duration: TimeInterval = 0
    private var startTime: Date?
    private var pausedAt: Date?
    private var accumulatedPause: TimeInterval = 0
    private var isPaused = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.buttonSize, height: Self.buttonSize)
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func start(duration: TimeInterval) {
        self.duration = duration
        startTime = Date()
        accumulatedPause = 0
        isPaused = false
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        pausedAt = Date()
    }

    func resume() {
        guard isPaused else { return }
        if let pausedAt {
            accumulatedPause += Date().timeIntervalSince(pausedAt)
        }
        self.pausedAt = nil
        isPaused = false
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 0

        trackLayer.strokeColor = NSColor.white.withAlphaComponent(0.2).cgColor
        trackLayer.fillColor = NSColor.clear.cgColor
        trackLayer.lineWidth = 2
        layer?.addSublayer(trackLayer)

        progressLayer.strokeColor = NSColor.white.cgColor
        progressLayer.fillColor = NSColor.clear.cgColor
        progressLayer.lineWidth = 2
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 1
        layer?.addSublayer(progressLayer)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        let closeImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(symbolConfig)
        image = closeImage
        imagePosition = .imageOnly
        contentTintColor = .white
        isBordered = false
    }

    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) / 2
        layer?.cornerRadius = radius
        let inset: CGFloat = 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(ovalIn: rect).cgPathCompat
        trackLayer.frame = bounds
        trackLayer.path = path
        progressLayer.frame = bounds
        progressLayer.path = path
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard let startTime, duration > 0 else { return }
        if isPaused { return }
        let elapsed = Date().timeIntervalSince(startTime) - accumulatedPause
        let progress = max(0, min(1, 1 - (elapsed / duration)))
        progressLayer.strokeEnd = CGFloat(progress)
        if elapsed >= duration {
            stop()
            onTimeout?()
        }
    }

    deinit {
        stop()
    }
}

// MARK: - macOS 13 compatibility

private extension NSBezierPath {
    /// `NSBezierPath.cgPath` is only available on macOS 14+.
    var cgPathCompat: CGPath {
        if #available(macOS 14.0, *) {
            return self.cgPath
        }

        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                // points[0] = control, points[1] = end
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
