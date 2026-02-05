import AppKit

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let onboardingVC = OnboardingViewController()
    private var isAppTerminating = false
    private var terminateObserver: Any?

    init() {
        // Default to step 01 size; subsequent steps resize dynamically.
        let initialContentSize = OnboardingViewController.preferredContentSize(for: .welcome)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialContentSize.width, height: initialContentSize.height),
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
        window.contentMinSize = initialContentSize
        window.contentMaxSize = initialContentSize
        window.center()
        window.contentViewController = onboardingVC
        // Use normal level so System Settings can come to front when opening permission panes.
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
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
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppTerminating = true
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }

    func show(startingAt step: OnboardingStep) {
        AppLog.log(.info, "onboarding", "OnboardingWindowController.show startingAt=\(step.rawValue)")
        let normalized = OnboardingAutoAdvance.normalizeStartStep(
            stored: step,
            screenRecordingGranted: ScreenRecordingGate.hasPermission(),
            accessibilityGranted: ClipboardAutoPasteService.shared.hasAccessibilityPermission
        )
        AppLog.log(.info, "onboarding", "OnboardingWindowController.show normalizedStart=\(normalized.rawValue) screenRecordingGranted=\(ScreenRecordingGate.hasPermission()) accessibilityGranted=\(ClipboardAutoPasteService.shared.hasAccessibilityPermission)")
        onboardingVC.start(at: normalized)
        guard let window else { return }

        // Ensure the window is the correct size for the start step.
        let targetContentSize = OnboardingViewController.preferredContentSize(for: normalized)
        window.contentMinSize = targetContentSize
        window.contentMaxSize = targetContentSize
        window.setContentSize(targetContentSize)

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // No-op.
        //
        // Important: do NOT mark onboarding as completed here.
        // This delegate method is also called during app termination (e.g. when macOS asks
        // the user to Quit & Reopen after granting Screen Recording permission). Marking
        // completion here would incorrectly prevent onboarding from resuming after relaunch.
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Only treat this as a "dismiss" when the user closes the window.
        // During app termination (e.g. Quit & Reopen after granting Screen Recording),
        // we must NOT mark dismissed.
        if !isAppTerminating {
            OnboardingStore.shared.markDismissed()
        }
        return true
    }
}

