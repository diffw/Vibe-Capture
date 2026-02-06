import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let captureManager = CaptureManager()
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var didBecomeActiveObserver: Any?
    private var uiTestCaptureModal: CaptureModalWindowController?
    private var shouldForceShowOnboarding = false
    private var shouldResetOnboardingAtLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.bootstrap()
        AppLog.log(
            .info,
            "app",
            "launch pid=\(ProcessInfo.processInfo.processIdentifier) bundle_id=\(Bundle.main.bundleIdentifier ?? "nil") bundle_path=\(Bundle.main.bundlePath) log_path=\(AppLog.logURL().path) args=\(ProcessInfo.processInfo.arguments.joined(separator: " "))"
        )

        let beforePolicy = NSApp.activationPolicy()
        let didSet = NSApp.setActivationPolicy(.accessory)
        let afterPolicy = NSApp.activationPolicy()
        NSLog("VibeCapture launch: activationPolicy before=%{public}@ after=%{public}@ didSet=%{public}@", "\(beforePolicy)", "\(afterPolicy)", "\(didSet)")

        // Read launch args early so menus can include debug items.
        let args = ProcessInfo.processInfo.arguments
        let isUITesting = args.contains(where: { $0.hasPrefix("--uitesting-") })
        shouldForceShowOnboarding = args.contains("--debug-show-onboarding") || args.contains("--show-onboarding")
        shouldResetOnboardingAtLaunch = args.contains("--reset-onboarding") || args.contains("--debug-reset-onboarding")

        setupStatusItem()
        setupMainMenu()

        ShortcutManager.shared.onHotKey = { [weak self] in
            self?.captureArea(nil)
        }
        ShortcutManager.shared.start()

        // IAP: start entitlements service and refresh on foreground.
        EntitlementsService.shared.start()
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await EntitlementsService.shared.refreshEntitlements() }
        }

        // UI testing helpers (launch-arg gated).
        if args.contains("--force-free") || args.contains("--free-mode") {
            EntitlementsService.shared.setStatus(
                ProStatus(tier: .free, source: .none, lastRefreshedAt: Date())
            )
        } else if args.contains("--force-pro") {
            EntitlementsService.shared.setStatus(
                ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date())
            )
        }

        // This is a menu bar app (no Dock icon/window). Show a one-time hint so launch doesn't feel like "nothing happened".
        let key = "didShowLaunchHUD"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            HUDService.shared.show(message: L("hud.app_running"), style: .info, duration: 0.9)
        }

        // UI testing helper: open paywall deterministically without relying on menu bar item labels.
        // This is gated behind a launch argument so it won't affect real users.
        if args.contains("--uitesting-open-paywall") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                PaywallWindowController.shared.show()
            }
        }

        // UI testing helper: open a capture modal with a synthetic image (no screen-recording permission needed).
        if args.contains("--uitesting-open-capture-modal") {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let size = NSSize(width: 900, height: 600)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(calibratedWhite: 0.9, alpha: 1.0).setFill()
                NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                image.unlockFocus()

                let session = CaptureSession(image: image, prompt: "", createdAt: Date())
                let modal = CaptureModalWindowController(session: session) { _ in }
                self.uiTestCaptureModal = modal
                modal.show()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }

        // Onboarding: show on first launch (unless UI testing launch args are present).
        if !isUITesting {
            if shouldForceShowOnboarding {
                showOnboarding(force: true, reset: shouldResetOnboardingAtLaunch)
            } else {
                showOnboardingIfNeeded()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }
        EntitlementsService.shared.stop()
    }

    /// Setup main menu with Edit menu so ⌘+A/C/V/X work in text fields
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (required)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: L("menu.app.quit_vibecap"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (enables ⌘+A/C/V/X in text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L("menu.edit"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.redo"), action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: L("menu.edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.select_all"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // 使用自定义模板图标（自动适应亮色/暗色模式）
            var iconImage: NSImage?
            
            // 尝试从 bundle 加载
            if let resourcePath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png") {
                iconImage = NSImage(contentsOfFile: resourcePath)
            } else if let resourcePath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png", inDirectory: "Resources") {
                // When `VibeCapture/Resources` is added as a folder reference, it gets copied into the app bundle
                // as a subdirectory named "Resources".
                iconImage = NSImage(contentsOfFile: resourcePath)
            }
            
            if let image = iconImage {
                image.size = NSSize(width: 16, height: 16)
                image.isTemplate = true  // 自动适应亮色/暗色模式
                button.image = image
            } else {
                // 回退到 SF Symbol
                let image = NSImage(
                    systemSymbolName: "camera.viewfinder",
                    accessibilityDescription: "VibeCap"
                )
                image?.isTemplate = true
                button.image = image
            }
        }

        let menu = NSMenu()
        // Avoid validateUserInterfaceItem surprises in a menu bar app.
        menu.autoenablesItems = false
        let captureItem = NSMenuItem(title: L("menu.capture_area"), action: #selector(captureArea(_:)), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        let upgradeItem = NSMenuItem(title: L("menu.upgrade"), action: #selector(openUpgrade(_:)), keyEquivalent: "")
        upgradeItem.target = self
        menu.addItem(upgradeItem)

        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Diagnostics (always available; helps debug permission + onboarding relaunch issues).
        menu.addItem(.separator())
        let diagnosticsItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        let diagnosticsMenu = NSMenu()
        diagnosticsMenu.autoenablesItems = false
        let openLogsItem = NSMenuItem(title: "Open Log File", action: #selector(openLogFile(_:)), keyEquivalent: "")
        openLogsItem.target = self
        diagnosticsMenu.addItem(openLogsItem)
        let copyLogsItem = NSMenuItem(title: "Copy Recent Logs", action: #selector(copyRecentLogs(_:)), keyEquivalent: "")
        copyLogsItem.target = self
        diagnosticsMenu.addItem(copyLogsItem)
        diagnosticsMenu.addItem(.separator())
        let copyStateItem = NSMenuItem(title: "Copy Onboarding State", action: #selector(copyOnboardingState(_:)), keyEquivalent: "")
        copyStateItem.target = self
        diagnosticsMenu.addItem(copyStateItem)
        let logStateItem = NSMenuItem(title: "Log Onboarding Diagnostics", action: #selector(logOnboardingDiagnostics(_:)), keyEquivalent: "")
        logStateItem.target = self
        diagnosticsMenu.addItem(logStateItem)
        diagnosticsItem.submenu = diagnosticsMenu
        menu.addItem(diagnosticsItem)

        // Debug utilities (only shown when explicitly enabled via launch args).
        if shouldForceShowOnboarding {
            menu.addItem(.separator())
            let showOnboardingItem = NSMenuItem(title: "Show Onboarding (Debug)", action: #selector(showOnboardingDebug(_:)), keyEquivalent: "")
            showOnboardingItem.target = self
            menu.addItem(showOnboardingItem)

            let resetAndShowOnboardingItem = NSMenuItem(title: "Reset + Show Onboarding (Debug)", action: #selector(resetAndShowOnboardingDebug(_:)), keyEquivalent: "")
            resetAndShowOnboardingItem.target = self
            menu.addItem(resetAndShowOnboardingItem)
        }
        menu.addItem(.separator())
        
        // Language submenu
        let languageItem = NSMenuItem(title: L("menu.language"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        buildLanguageMenu(languageMenu)
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }
    
    /// Build the Language submenu with all supported languages
    private func buildLanguageMenu(_ menu: NSMenu) {
        let override = LocalizationManager.shared.getLanguageOverride()
        
        // System Language option (uses system preference)
        let systemItem = NSMenuItem(title: L("menu.language.system_default"), action: #selector(setSystemLanguage(_:)), keyEquivalent: "")
        systemItem.target = self
        if override == nil {
            systemItem.state = .on
        }
        menu.addItem(systemItem)
        menu.addItem(.separator())
        
        // All supported languages
        for (code, displayName) in LocalizationManager.supportedLanguages {
            let item = NSMenuItem(title: displayName, action: #selector(setLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            if override == code {
                item.state = .on
            }
            menu.addItem(item)
        }
    }
    
    @objc private func setSystemLanguage(_ sender: Any?) {
        if interceptMenuActionToResumeOnboardingIfNeeded() { return }
        LocalizationManager.shared.setLanguageOverride(nil)
        showRestartAlert()
    }
    
    @objc private func setLanguage(_ sender: NSMenuItem) {
        if interceptMenuActionToResumeOnboardingIfNeeded() { return }
        guard let code = sender.representedObject as? String else { return }
        LocalizationManager.shared.setLanguageOverride(code)
        showRestartAlert()
    }
    
    private func showRestartAlert() {
        // Use the NEW language for the alert (the one user just selected)
        let newLang = LocalizationManager.shared.getEffectiveLanguage()
        
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.localizedString(forKey: "alert.restart.title", language: newLang)
        alert.informativeText = LocalizationManager.shared.localizedString(forKey: "alert.restart.message", language: newLang)
        alert.addButton(withTitle: LocalizationManager.shared.localizedString(forKey: "button.restart_now", language: newLang))
        alert.addButton(withTitle: LocalizationManager.shared.localizedString(forKey: "button.later", language: newLang))
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppRelauncher.restart()
        }
    }

    @objc private func captureArea(_ sender: Any?) {
        AppLog.log(.info, "capture", "captureArea invoked")
        if interceptMenuActionToResumeOnboardingIfNeeded() {
            AppLog.log(.info, "capture", "captureArea intercepted by onboarding resume logic")
            return
        }
        AppLog.log(.info, "capture", "captureArea proceeding to startCapture")
        captureManager.startCapture()
    }

    @objc private func openSettings(_ sender: Any?) {
        if interceptMenuActionToResumeOnboardingIfNeeded() { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    @objc private func openUpgrade(_ sender: Any?) {
        if interceptMenuActionToResumeOnboardingIfNeeded() { return }
        PaywallWindowController.shared.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - Onboarding

    private func showOnboardingIfNeeded() {
        let store = OnboardingStore.shared
        let markerStep = store.consumeResumeMarkerIfPresent()
        if let markerStep {
            // Apply minimum step from the marker (more durable than UserDefaults on fast termination).
            if store.step.index < markerStep.index {
                store.step = markerStep
            }
        }

        let shouldResume = store.shouldResumeAfterRestart || (markerStep != nil)
        if shouldResume {
            AppLog.log(.info, "onboarding", "showOnboardingIfNeeded: resuming after restart \(store.debugSnapshot())")
            showOnboarding(force: true, reset: false)
            // One-shot: once we resumed after a system-driven restart, clear the flag.
            store.shouldResumeAfterRestart = false
            return
        }
        // Auto-show only on first run; if user dismissed, don't auto-show again.
        guard !store.isFlowCompleted else { return }
        guard store.dismissedAt == nil else { return }
        AppLog.log(.info, "onboarding", "showOnboardingIfNeeded: first-run auto-show \(store.debugSnapshot())")
        showOnboarding(force: false, reset: false)
    }

    private func showOnboarding(force: Bool, reset: Bool) {
        let store = OnboardingStore.shared
        if reset {
            store.resetForDebug()
        }
        if !force, store.isFlowCompleted { return }
        store.markStartedIfNeeded()

        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
        }
        AppLog.log(.info, "onboarding", "showOnboarding force=\(force) reset=\(reset) startingAt=\(store.step.rawValue) \(store.debugSnapshot())")
        onboardingWindowController?.show(startingAt: store.step)
    }

    @objc private func showOnboardingDebug(_ sender: Any?) {
        HUDService.shared.show(message: "Debug: Show Onboarding", style: .info, duration: 0.7)
        // Defer until after NSMenu tracking finishes.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showOnboarding(force: true, reset: false)
            self.debugReportOnboardingWindowState()
        }
    }

    @objc private func resetAndShowOnboardingDebug(_ sender: Any?) {
        HUDService.shared.show(message: "Debug: Reset + Show Onboarding", style: .info, duration: 0.9)
        // Defer until after NSMenu tracking finishes.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showOnboarding(force: true, reset: true)
            self.debugReportOnboardingWindowState()
        }
    }

    /// If onboarding isn't finished, intercept menu actions and show onboarding instead.
    /// This is used as a fallback after system-driven "Quit & Reopen".
    /// NOTE: Does NOT intercept if user has progressed past screen recording step (skip allowed).
    private func interceptMenuActionToResumeOnboardingIfNeeded() -> Bool {
        let store = OnboardingStore.shared
        // If onboarding has been started but not completed, resume it on any menu action.
        guard !store.isFlowCompleted else { return false }
        guard store.startedAt != nil else { return false }

        // If user has progressed past screenRecording step (e.g. skipped), don't block capture.
        // Let CaptureManager handle permission check and show Gate if needed.
        if store.step.index > OnboardingStep.screenRecording.index {
            AppLog.log(.info, "onboarding", "interceptMenuActionToResumeOnboardingIfNeeded: user past screenRecording, not intercepting \(store.debugSnapshot())")
            return false
        }

        AppLog.log(.info, "onboarding", "interceptMenuActionToResumeOnboardingIfNeeded: intercepting menu action \(store.debugSnapshot())")
        // Defer until after NSMenu tracking finishes.
        DispatchQueue.main.async { [weak self] in
            self?.showOnboarding(force: true, reset: false)
        }
        return true
    }

    private func debugReportOnboardingWindowState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard let window = self.onboardingWindowController?.window else {
                HUDService.shared.show(message: "Debug: onboarding window=nil", style: .error, duration: 1.2)
                return
            }
            let frame = window.frame
            let frameDesc = "(\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.size.width))×\(Int(frame.size.height)))"
            HUDService.shared.show(message: "Debug: onboarding visible=\(window.isVisible) frame=\(frameDesc)", style: .info, duration: 1.4)
        }
    }

    // MARK: - Diagnostics actions

    @objc private func openLogFile(_ sender: Any?) {
        NSWorkspace.shared.open(AppLog.logURL())
    }

    @objc private func copyRecentLogs(_ sender: Any?) {
        let text = AppLog.tail(maxBytes: 48_000)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        HUDService.shared.show(message: "Copied recent logs", style: .info, duration: 0.8)
    }

    @objc private func copyOnboardingState(_ sender: Any?) {
        let store = OnboardingStore.shared
        let text =
            "bundle_path=\(Bundle.main.bundlePath)\n" +
            "screenRecordingGranted=\(ScreenRecordingGate.hasPermission()) accessibilityGranted=\(ClipboardAutoPasteService.shared.hasAccessibilityPermission)\n" +
            store.debugSnapshot() + "\n"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        HUDService.shared.show(message: "Copied onboarding state", style: .info, duration: 0.8)
    }

    @objc private func logOnboardingDiagnostics(_ sender: Any?) {
        let store = OnboardingStore.shared
        AppLog.log(
            .info,
            "onboarding",
            "diagnostics bundle_path=\(Bundle.main.bundlePath) screenRecordingGranted=\(ScreenRecordingGate.hasPermission()) accessibilityGranted=\(ClipboardAutoPasteService.shared.hasAccessibilityPermission) \(store.debugSnapshot())"
        )
        HUDService.shared.show(message: "Logged diagnostics", style: .info, duration: 0.8)
    }
}



