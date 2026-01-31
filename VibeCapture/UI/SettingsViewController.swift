import AppKit

final class SettingsViewController: NSViewController {
    private let shortcutRecorder = ShortcutRecorderView()

    // Save section
    private let saveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveFolderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "", target: nil, action: nil)

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    
    // Pro section (IAP)
    private let proTitleLabel = NSTextField(labelWithString: "")
    private let proStatusLabel = NSTextField(labelWithString: "")
    private let upgradeButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)
    private let manageButton = NSButton(title: "", target: nil, action: nil)
    private var proStatusObserver: Any?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        shortcutRecorder.onChange = { [weak self] combo in
            self?.applyShortcut(combo)
        }

        // Pro section
        proTitleLabel.stringValue = L("settings.pro.section_title")
        proTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        proStatusLabel.textColor = .secondaryLabelColor
        proStatusLabel.font = NSFont.systemFont(ofSize: 12)
        proStatusLabel.maximumNumberOfLines = 2

        upgradeButton.title = L("settings.pro.action.upgrade")
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradePressed)

        restoreButton.title = L("settings.pro.action.restore")
        restoreButton.target = self
        restoreButton.action = #selector(restorePressed)

        manageButton.title = L("settings.pro.action.manage")
        manageButton.target = self
        manageButton.action = #selector(managePressed)

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

        // Pro section layout
        let proButtonsRow = NSStackView(views: [upgradeButton, restoreButton, manageButton, NSView()])
        proButtonsRow.orientation = .horizontal
        proButtonsRow.alignment = .centerY
        proButtonsRow.spacing = 8
        let proSection = NSStackView(views: [proTitleLabel, proStatusLabel, proButtonsRow])
        proSection.orientation = .vertical
        proSection.spacing = 6
        
        let stack = NSStackView(views: [
            shortcutRecorder,
            divider(),
            saveSection,
            divider(),
            proSection,
            divider(),
            launchAtLoginCheckbox,
            NSView()
        ])
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
        refreshProStatus()
        startProStatusObserver()
    }

    deinit {
        stopProStatusObserver()
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

    // MARK: - Pro / IAP

    private func startProStatusObserver() {
        guard proStatusObserver == nil else { return }
        proStatusObserver = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshProStatus()
        }
    }

    private func stopProStatusObserver() {
        if let proStatusObserver {
            NotificationCenter.default.removeObserver(proStatusObserver)
            self.proStatusObserver = nil
        }
    }

    private func refreshProStatus() {
        let status = EntitlementsService.shared.status

        let tierLabel: String = (status.tier == .pro) ? L("settings.proStatus.pro") : L("settings.proStatus.free")
        let sourceLabelKey: String
        switch status.source {
        case .monthly: sourceLabelKey = "settings.proStatus.source.monthly"
        case .yearly: sourceLabelKey = "settings.proStatus.source.yearly"
        case .lifetime: sourceLabelKey = "settings.proStatus.source.lifetime"
        case .none: sourceLabelKey = "settings.proStatus.source.none"
        case .unknown: sourceLabelKey = "settings.proStatus.source.unknown"
        }

        let refreshed: String
        if let date = status.lastRefreshedAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateStyle = .short
            f.timeStyle = .short
            refreshed = f.string(from: date)
        } else {
            refreshed = "-"
        }

        let sourceLabel = L(sourceLabelKey)
        proStatusLabel.stringValue = "\(tierLabel)\n\(L("settings.proStatus.lastRefreshed")) \(refreshed)\n\(L("settings.proStatus.source", sourceLabel))"
    }

    @objc private func upgradePressed() {
        PaywallWindowController.shared.show()
    }

    @objc private func restorePressed() {
        PurchaseService.shared.restorePurchases(from: view.window)
    }

    @objc private func managePressed() {
        PurchaseService.shared.openManageSubscriptions(from: view.window)
    }
}
