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
        window.title = "Add to Send List"
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
    private let chooseButton = NSButton(title: "Choose from Applications...", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    
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
        let headerLabel = NSTextField(labelWithString: "Running Apps:")
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
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseFromApplications)
        
        // Done button (changes save immediately, so only need Done)
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
        
        runningApps = apps.map { app in
            let isAdded = AppDetectionService.shared.isWhitelisted(bundleID: app.bundleIdentifier)
            let isUserAdded = SettingsStore.shared.isInUserWhitelist(bundleID: app.bundleIdentifier)
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
        panel.message = "Select an application to add to the Send List"
        
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.addAppFromURL(url)
        }
    }
    
    private func addAppFromURL(_ url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            showAlert(title: "Invalid Application", message: "Could not read application bundle.")
            return
        }
        
        // Check if blacklisted
        if AppDetectionService.shared.isBlacklisted(bundleID: bundleID) {
            showAlert(title: "Cannot Add App", message: "This app doesn't support image paste.")
            return
        }
        
        // Check if already added
        if AppDetectionService.shared.isWhitelisted(bundleID: bundleID) {
            showAlert(title: "Already Added", message: "This app is already in the Send List.")
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
        
        SettingsStore.shared.addUserWhitelistApp(userApp)
        loadRunningApps()
        onAppAdded?()
    }
    
    private func addApp(_ appInfo: AppInfo) {
        // Check if blacklisted
        if appInfo.isBlacklisted {
            showAlert(title: "Cannot Add App", message: "This app doesn't support image paste.")
            return
        }
        
        // If already added by user, remove it (toggle behavior)
        if appInfo.isAdded && SettingsStore.shared.isInUserWhitelist(bundleID: appInfo.bundleID) {
            SettingsStore.shared.removeUserWhitelistApp(bundleID: appInfo.bundleID)
            loadRunningApps()
            onAppAdded?()
            return
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
        
        SettingsStore.shared.addUserWhitelistApp(userApp)
        loadRunningApps()
        onAppAdded?()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
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
            statusLabel.stringValue = "Built-in"
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
