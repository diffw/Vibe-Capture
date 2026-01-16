import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let captureManager = CaptureManager()
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // This is a menu bar app (no Dock icon/window). Show a one-time hint so launch doesn't feel like "nothing happened".
        let key = "didShowLaunchHUD"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            HUDService.shared.show(message: "VibeCap is running", style: .info, duration: 0.9)
        }
    }

    /// Setup main menu with Edit menu so ⌘+A/C/V/X work in text fields
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (required)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit VibeCap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (enables ⌘+A/C/V/X in text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
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
        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        statusItem.menu = menu
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

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}



