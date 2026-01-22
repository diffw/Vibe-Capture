import AppKit

final class SettingsViewController: NSViewController {
    private let shortcutRecorder = ShortcutRecorderView()

    // Save section
    private let saveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveFolderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "", target: nil, action: nil)

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    
    // Send List section
    private let sendListLabel = NSTextField(labelWithString: "")
    private let sendListScrollView = NSScrollView()
    private let sendListTableView = NSTableView()
    private let addAppButton = NSButton(title: "+", target: nil, action: nil)
    private let removeAppButton = NSButton(title: "−", target: nil, action: nil)
    private var userApps: [UserWhitelistApp] = []

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        shortcutRecorder.onChange = { [weak self] combo in
            self?.applyShortcut(combo)
        }

        // Save section
        saveCheckbox.title = L("settings.save.checkbox")
        saveCheckbox.target = self
        saveCheckbox.action = #selector(saveToggled)
        saveCheckbox.state = SettingsStore.shared.saveEnabled ? .on : .off

        saveFolderLabel.textColor = .secondaryLabelColor
        saveFolderLabel.font = NSFont.systemFont(ofSize: 12)
        saveFolderLabel.lineBreakMode = .byTruncatingMiddle

        chooseFolderButton.title = L("settings.save.choose_folder")
        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolderPressed)

        launchAtLoginCheckbox.title = L("settings.login.checkbox")
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginToggled)
        launchAtLoginCheckbox.state = LaunchAtLoginService.shared.isEnabled ? .on : .off

        // Save row
        let saveRow = NSStackView(views: [chooseFolderButton, NSView(), saveFolderLabel])
        saveRow.orientation = .horizontal
        saveRow.alignment = .centerY
        saveRow.spacing = 8

        let saveSection = NSStackView(views: [saveCheckbox, saveRow])
        saveSection.orientation = .vertical
        saveSection.spacing = 6
        
        // Send List section
        sendListLabel.stringValue = L("settings.send_list.title")
        sendListLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        sendListTableView.delegate = self
        sendListTableView.dataSource = self
        sendListTableView.rowHeight = 28
        sendListTableView.headerView = nil
        sendListTableView.backgroundColor = .clear
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        column.width = 200
        sendListTableView.addTableColumn(column)
        
        sendListScrollView.documentView = sendListTableView
        sendListScrollView.hasVerticalScroller = true
        sendListScrollView.borderType = .bezelBorder
        sendListScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        addAppButton.bezelStyle = .smallSquare
        addAppButton.target = self
        addAppButton.action = #selector(addAppPressed)
        addAppButton.setContentHuggingPriority(.required, for: .horizontal)
        
        removeAppButton.bezelStyle = .smallSquare
        removeAppButton.target = self
        removeAppButton.action = #selector(removeAppPressed)
        removeAppButton.setContentHuggingPriority(.required, for: .horizontal)
        
        let buttonStack = NSStackView(views: [addAppButton, removeAppButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 0
        
        let sendListSection = NSStackView(views: [sendListLabel, sendListScrollView, buttonStack])
        sendListSection.orientation = .vertical
        sendListSection.alignment = .leading
        sendListSection.spacing = 6
        
        // Set constraints for scroll view
        NSLayoutConstraint.activate([
            sendListScrollView.heightAnchor.constraint(equalToConstant: 100),
            sendListScrollView.widthAnchor.constraint(equalToConstant: 250),
        ])
        
        loadUserApps()

        let stack = NSStackView(views: [shortcutRecorder, divider(), saveSection, divider(), sendListSection, divider(), launchAtLoginCheckbox, NSView()])
        stack.orientation = .vertical
        stack.spacing = 14

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])

        refreshSaveFolderLabel()
    }

    private func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func applyShortcut(_ combo: KeyCombo) {
        do {
            try ShortcutManager.shared.updateHotKey(combo)
        } catch {
            // Revert UI to stored value.
            let current = SettingsStore.shared.captureHotKey
            shortcutRecorder.setCombo(current)
            showError(title: L("error.shortcut_unavailable"), message: error.localizedDescription)
        }
    }

    @objc private func saveToggled() {
        SettingsStore.shared.saveEnabled = (saveCheckbox.state == .on)
        refreshSaveFolderLabel()
    }

    @objc private func chooseFolderPressed() {
        do {
            if let url = try ScreenshotSaveService.shared.chooseAndStoreFolder() {
                HUDService.shared.show(message: L("hud.folder_selected"), style: .success)
                saveFolderLabel.stringValue = url.path
            }
        } catch {
            showError(title: L("error.unable_to_set_folder"), message: error.localizedDescription)
        }
    }

    @objc private func launchAtLoginToggled() {
        let enabled = (launchAtLoginCheckbox.state == .on)
        do {
            try LaunchAtLoginService.shared.setEnabled(enabled)
            SettingsStore.shared.launchAtLogin = enabled
            if enabled, LaunchAtLoginService.shared.status == .requiresApproval {
                showLaunchApprovalAlert()
            }
        } catch LaunchAtLoginError.requiresApproval {
            SettingsStore.shared.launchAtLogin = enabled
            showLaunchApprovalAlert()
        } catch {
            // Revert checkbox.
            launchAtLoginCheckbox.state = enabled ? .off : .on
            showError(title: L("error.launch_login_failed"), message: error.localizedDescription)
        }
    }

    private func showLaunchApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = L("permission.login.approval_required")
        alert.informativeText = L("permission.login.message")
        alert.addButton(withTitle: L("button.open_login_items"))
        alert.addButton(withTitle: L("button.ok"))
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            LaunchAtLoginService.openLoginItemsSettings()
        }
    }

    private func refreshSaveFolderLabel() {
        if let url = ScreenshotSaveService.shared.currentFolderURL() {
            saveFolderLabel.stringValue = url.path
        } else {
            saveFolderLabel.stringValue = L("settings.save.no_folder")
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L("button.ok"))
        alert.runModal()
    }
    
    // MARK: - Send List Management
    
    private func loadUserApps() {
        userApps = SettingsStore.shared.userWhitelistApps
        sendListTableView.reloadData()
        updateRemoveButtonState()
    }
    
    private func updateRemoveButtonState() {
        removeAppButton.isEnabled = sendListTableView.selectedRow >= 0
    }
    
    @objc private func addAppPressed() {
        guard let window = view.window else { return }
        let panelController = AddAppPanelController { [weak self] in
            self?.loadUserApps()
        }
        panelController.showAsSheet(relativeTo: window)
    }
    
    @objc private func removeAppPressed() {
        let row = sendListTableView.selectedRow
        guard row >= 0 && row < userApps.count else { return }
        
        let app = userApps[row]
        SettingsStore.shared.removeUserWhitelistApp(bundleID: app.bundleID)
        loadUserApps()
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension SettingsViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return userApps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = userApps[row]
        
        let cellView = NSTableCellView()
        
        // Icon
        let icon = NSWorkspace.shared.icon(forFile: app.appPath)
        let imageView = NSImageView(image: icon)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Name label
        let nameLabel = NSTextField(labelWithString: app.displayName)
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        cellView.addSubview(imageView)
        cellView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            
            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            nameLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -4),
        ])
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }
}



