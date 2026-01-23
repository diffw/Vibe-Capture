import AppKit

/// Controller for the "Add to Send List" panel
final class AddAppPanelController: NSWindowController {
    
    private var onAppAdded: (() -> Void)?
    
    convenience init(onAppAdded: (() -> Void)? = nil) {
        let viewController = AddAppViewController()
        viewController.onAppAdded = onAppAdded
        
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("add_app.window_title")
        window.contentViewController = viewController
        window.isMovableByWindowBackground = true
        window.center()
        
        self.init(window: window)
        self.onAppAdded = onAppAdded
    }
    
    func showAsSheet(relativeTo parentWindow: NSWindow) {
        guard let window = self.window else { return }
        parentWindow.beginSheet(window) { _ in }
    }
    
    func showAsWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// View controller for the Add App panel
final class AddAppViewController: NSViewController {
    
    var onAppAdded: (() -> Void)?
    
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let chooseButton = NSButton(title: "", target: nil, action: nil)
    private let doneButton = NSButton(title: "", target: nil, action: nil)
    
    private var runningApps: [AppInfo] = []
    
    private struct AppInfo {
        let bundleID: String
        let displayName: String
        let icon: NSImage?
        let appPath: String
        let isAdded: Bool  // Already in whitelist (official or user)
        let isUserAdded: Bool  // Added by user (can be removed)
        let isBlacklisted: Bool
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadRunningApps()
    }
    
    private func setupUI() {
        // Header label
        let headerLabel = NSTextField(labelWithString: L("add_app.header"))
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        // Table view setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 36
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        column.width = 280
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        // Choose button
        chooseButton.title = L("add_app.choose_from_apps")
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseFromApplications)
        
        // Done button (changes save immediately, so only need Done)
        doneButton.title = L("add_app.done")
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(donePressed)
        doneButton.keyEquivalent = "\u{1b}" // ESC to close (Enter also works via default button)
        
        // Button row - only Done button, right-aligned
        let buttonRow = NSStackView(views: [NSView(), doneButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill
        
        // Layout
        let mainStack = NSStackView(views: [headerLabel, scrollView, chooseButton, buttonRow])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            scrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            chooseButton.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
        ])
    }
    
    private func loadRunningApps() {
        let apps = AppDetectionService.shared.getAllRunningApps()
        let isPro = EntitlementsService.shared.isPro
        
        runningApps = apps.map { app in
            let isAdded = AppDetectionService.shared.isWhitelisted(bundleID: app.bundleIdentifier)
            let isUserAdded = SettingsStore.shared.isInUserWhitelist(bundleID: app.bundleIdentifier, isPro: isPro)
            let isBlacklisted = AppDetectionService.shared.isBlacklisted(bundleID: app.bundleIdentifier)
            let appPath = app.runningApp?.bundleURL?.path ?? ""
            
            return AppInfo(
                bundleID: app.bundleIdentifier,
                displayName: app.displayName,
                icon: app.icon,
                appPath: appPath,
                isAdded: isAdded,
                isUserAdded: isUserAdded,
                isBlacklisted: isBlacklisted
            )
        }
        
        tableView.reloadData()
    }
    
    @objc private func chooseFromApplications() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L("add_app.panel_message")
        
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.addAppFromURL(url)
        }
    }
    
    private func addAppFromURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            showAlert(title: L("error.invalid_application"), message: L("error.could_not_read_bundle"))
            return
        }
        
        // Check if blacklisted
        if AppDetectionService.shared.isBlacklisted(bundleID: bundleID) {
            showAlert(title: L("error.cannot_add_app"), message: L("error.app_no_paste_support"))
            return
        }

        // If it's in official whitelist, it does not count towards the Free slot.
        if AppDetectionService.shared.isOfficialWhitelisted(bundleID: bundleID) {
            showAlert(title: L("gating.customApp.notCounted.title"), message: L("gating.customApp.notCounted.message"))
            return
        }
        
        // Check if already added (user-added, depending on Free/Pro effective list)
        if SettingsStore.shared.isInUserWhitelist(bundleID: bundleID, isPro: EntitlementsService.shared.isPro) {
            showAlert(title: L("error.already_added"), message: L("error.app_already_in_list"))
            return
        }
        
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String 
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        let userApp = UserWhitelistApp(
            bundleID: bundleID,
            displayName: displayName,
            appPath: url.path
        )

        if EntitlementsService.shared.isPro {
            SettingsStore.shared.addProUserWhitelistApp(userApp)
        } else {
            // Free: only one pinned custom app, add requires confirmation, cannot be removed.
            if SettingsStore.shared.freePinnedCustomApp != nil {
                PaywallWindowController.shared.show()
                return
            }
            if !confirmFreePinnedApp(displayName: displayName) {
                return
            }
            SettingsStore.shared.freePinnedCustomApp = userApp
        }
        loadRunningApps()
        onAppAdded?()
    }
    
    private func addApp(_ appInfo: AppInfo) {
        // Check if blacklisted
        if appInfo.isBlacklisted {
            showAlert(title: L("error.cannot_add_app"), message: L("error.app_no_paste_support"))
            return
        }

        // Official whitelist apps do not count towards Free slot.
        if AppDetectionService.shared.isOfficialWhitelisted(bundleID: appInfo.bundleID) {
            showAlert(title: L("gating.customApp.notCounted.title"), message: L("gating.customApp.notCounted.message"))
            return
        }
        
        if EntitlementsService.shared.isPro {
            // If already added by user, remove it (toggle behavior)
            if appInfo.isAdded && SettingsStore.shared.isInUserWhitelist(bundleID: appInfo.bundleID, isPro: true) {
                SettingsStore.shared.removeProUserWhitelistApp(bundleID: appInfo.bundleID)
                loadRunningApps()
                onAppAdded?()
                return
            }
        } else {
            // Free: pinned app cannot be removed.
            if let pinned = SettingsStore.shared.freePinnedCustomApp, pinned.bundleID == appInfo.bundleID {
                return
            }
        }
        
        // If it's in official whitelist (not user-added), do nothing
        if appInfo.isAdded {
            return
        }
        
        let userApp = UserWhitelistApp(
            bundleID: appInfo.bundleID,
            displayName: appInfo.displayName,
            appPath: appInfo.appPath
        )

        if EntitlementsService.shared.isPro {
            SettingsStore.shared.addProUserWhitelistApp(userApp)
        } else {
            if SettingsStore.shared.freePinnedCustomApp != nil {
                PaywallWindowController.shared.show()
                return
            }
            if !confirmFreePinnedApp(displayName: appInfo.displayName) {
                return
            }
            SettingsStore.shared.freePinnedCustomApp = userApp
        }
        loadRunningApps()
        onAppAdded?()
    }

    private func confirmFreePinnedApp(displayName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("gating.customApp.confirm.title")
        alert.informativeText = L("gating.customApp.confirm.message", displayName)
        alert.addButton(withTitle: L("gating.customApp.confirm.confirm"))
        alert.addButton(withTitle: L("button.cancel"))
        let resp = alert.runModal()
        return resp == .alertFirstButtonReturn
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button.ok"))
        alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
    
    @objc private func donePressed() {
        view.window?.sheetParent?.endSheet(view.window!)
        view.window?.close()
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension AddAppViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return runningApps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = runningApps[row]
        
        let cellView = NSTableCellView()
        
        // Icon
        let imageView = NSImageView()
        imageView.image = app.icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Name label
        let nameLabel = NSTextField(labelWithString: app.displayName)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Status label
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        if app.isUserAdded {
            // User-added: checkmark, clickable to remove
            statusLabel.stringValue = "✓"
            statusLabel.textColor = .systemGreen
            statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        } else if app.isAdded {
            // Official whitelist: built-in indicator
            statusLabel.stringValue = L("add_app.status.builtin")
            statusLabel.textColor = .tertiaryLabelColor
        } else if app.isBlacklisted {
            statusLabel.stringValue = "—"
            statusLabel.textColor = .tertiaryLabelColor
            nameLabel.textColor = .tertiaryLabelColor
        }
        
        cellView.addSubview(imageView)
        cellView.addSubview(nameLabel)
        cellView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            
            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),
            
            statusLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            statusLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < runningApps.count else { return }
        
        let app = runningApps[row]
        
        // Deselect immediately (we handle click, not selection)
        tableView.deselectRow(row)
        
        // Try to add the app
        addApp(app)
    }
}
