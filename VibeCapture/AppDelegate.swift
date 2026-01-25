import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let captureManager = CaptureManager()
    private var settingsWindowController: SettingsWindowController?
    private var didBecomeActiveObserver: Any?
    private var uiTestCaptureModal: CaptureModalWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.bootstrap()
        AppLog.log(.info, "app", "launch bundle_id=\(Bundle.main.bundleIdentifier ?? "nil") log_path=\(AppLog.logURL().path)")

        let beforePolicy = NSApp.activationPolicy()
        let didSet = NSApp.setActivationPolicy(.accessory)
        let afterPolicy = NSApp.activationPolicy()
        NSLog("VibeCapture launch: activationPolicy before=%{public}@ after=%{public}@ didSet=%{public}@", "\(beforePolicy)", "\(afterPolicy)", "\(didSet)")

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
        let args = ProcessInfo.processInfo.arguments
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                let size = NSSize(width: 900, height: 600)
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(calibratedWhite: 0.9, alpha: 1.0).setFill()
                NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                image.unlockFocus()

                let session = CaptureSession(image: image, prompt: "", createdAt: Date())
                let modal = CaptureModalWindowController(session: session, targetApp: nil) { _ in }
                self.uiTestCaptureModal = modal
                modal.show()
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
        menu.addItem(NSMenuItem(title: L("menu.capture_area"), action: #selector(captureArea(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L("menu.upgrade"), action: #selector(openUpgrade(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L("menu.settings"), action: #selector(openSettings(_:)), keyEquivalent: ""))
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
        LocalizationManager.shared.setLanguageOverride(nil)
        showRestartAlert()
    }
    
    @objc private func setLanguage(_ sender: NSMenuItem) {
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
            // Restart the app
            let url = URL(fileURLWithPath: Bundle.main.bundlePath)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    @objc private func captureArea(_ sender: Any?) {
        captureManager.startCapture()
    }

    @objc private func openSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    @objc private func openUpgrade(_ sender: Any?) {
        PaywallWindowController.shared.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}



