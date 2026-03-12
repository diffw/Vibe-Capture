import AppKit

final class SettingsViewController: NSViewController {
    private let shortcutRecorder = ShortcutRecorderView()
    private let contentInset: CGFloat = 24
    private let sectionSpacing: CGFloat = 10
    private let rowSpacing: CGFloat = 10
    private let leadingLabelWidth: CGFloat = 140
    private let statusLabelWidth: CGFloat = 76

    // Permissions section
    private let permissionsTitleLabel = NSTextField(labelWithString: "")
    private let screenRecordingStatusLabel = NSTextField(labelWithString: "")
    private let screenRecordingButton = NSButton(title: "", target: nil, action: nil)
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityButton = NSButton(title: "", target: nil, action: nil)
    private var permissionsObserver: Any?

    // Save section
    private let saveCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveFolderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "", target: nil, action: nil)

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let versionLabel = NSTextField(labelWithString: "")
    
    // Pro section (IAP)
    private let proTitleLabel = NSTextField(labelWithString: "")
    private let proStatusLabel = NSTextField(labelWithString: "")
    private let upgradeButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)
    private let manageButton = NSButton(title: "", target: nil, action: nil)
    private var proStatusObserver: Any?

    // Cleanup section
    private let cleanupTitleLabel = NSTextField(labelWithString: "")
    private let cleanupToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let cleanupIntervalLabel = NSTextField(labelWithString: "")
    private let cleanupIntervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cleanupInfoLabel = NSTextField(labelWithString: "")

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLog.log(.info, "settings", "SettingsViewController viewDidLoad layout=v2")
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        shortcutRecorder.onChange = { [weak self] combo in
            self?.applyShortcut(combo)
        }

        // Permissions section
        permissionsTitleLabel.stringValue = L("settings.permissions.section_title")
        permissionsTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        permissionsTitleLabel.textColor = .secondaryLabelColor

        screenRecordingButton.title = L("settings.permissions.screen_recording.open")
        screenRecordingButton.target = self
        screenRecordingButton.action = #selector(openScreenRecordingSettings)
        screenRecordingButton.bezelStyle = .rounded
        screenRecordingButton.controlSize = .small
        screenRecordingButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        accessibilityButton.title = L("settings.permissions.accessibility.open")
        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.controlSize = .small
        accessibilityButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        [screenRecordingStatusLabel, accessibilityStatusLabel].forEach { label in
            label.textColor = .secondaryLabelColor
            label.font = NSFont.systemFont(ofSize: 12)
            label.alignment = .right
        }
        screenRecordingStatusLabel.widthAnchor.constraint(equalToConstant: statusLabelWidth).isActive = true
        accessibilityStatusLabel.widthAnchor.constraint(equalToConstant: statusLabelWidth).isActive = true

        // Pro section
        proTitleLabel.stringValue = L("settings.pro.section_title")
        proTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        proTitleLabel.textColor = .secondaryLabelColor

        proStatusLabel.textColor = .secondaryLabelColor
        proStatusLabel.font = NSFont.systemFont(ofSize: 12)
        proStatusLabel.maximumNumberOfLines = 2

        upgradeButton.title = L("settings.pro.action.upgrade")
        upgradeButton.target = self
        upgradeButton.action = #selector(upgradePressed)
        upgradeButton.controlSize = .small
        upgradeButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        upgradeButton.bezelStyle = .rounded

        restoreButton.title = L("settings.pro.action.restore")
        restoreButton.target = self
        restoreButton.action = #selector(restorePressed)
        restoreButton.controlSize = .small
        restoreButton.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        restoreButton.bezelStyle = .rounded

        manageButton.title = L("settings.pro.action.manage")
        manageButton.target = self
        manageButton.action = #selector(managePressed)
        manageButton.controlSize = .small
        manageButton.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        manageButton.bezelStyle = .rounded

        // Cleanup section
        cleanupTitleLabel.stringValue = "Auto Cleanup"
        cleanupTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        cleanupTitleLabel.textColor = .secondaryLabelColor

        cleanupToggle.title = "Enable Auto Cleanup (Pro)"
        cleanupToggle.target = self
        cleanupToggle.action = #selector(cleanupToggled)
        cleanupToggle.state = SettingsStore.shared.autoCleanupEnabled ? .on : .off

        cleanupIntervalLabel.stringValue = "Interval"
        cleanupIntervalLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        cleanupIntervalLabel.widthAnchor.constraint(equalToConstant: leadingLabelWidth).isActive = true

        cleanupIntervalPopup.target = self
        cleanupIntervalPopup.action = #selector(cleanupIntervalChanged)
        cleanupIntervalPopup.controlSize = .small
        cleanupIntervalPopup.bezelStyle = .rounded
        cleanupIntervalPopup.removeAllItems()
        for option in CleanupIntervalOption.allCases {
            cleanupIntervalPopup.addItem(withTitle: option.label)
            cleanupIntervalPopup.lastItem?.tag = option.rawValue
        }

        cleanupInfoLabel.font = NSFont.systemFont(ofSize: 12)
        cleanupInfoLabel.textColor = .secondaryLabelColor
        cleanupInfoLabel.lineBreakMode = .byWordWrapping
        cleanupInfoLabel.maximumNumberOfLines = 2

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
        chooseFolderButton.controlSize = .small
        chooseFolderButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        chooseFolderButton.bezelStyle = .rounded

        launchAtLoginCheckbox.title = L("settings.login.checkbox")
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginToggled)
        launchAtLoginCheckbox.state = LaunchAtLoginService.shared.isEnabled ? .on : .off

        versionLabel.stringValue = versionString()
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.alignment = .left

        // Save row
        let saveRow = NSStackView(views: [chooseFolderButton, NSView(), saveFolderLabel])
        saveRow.orientation = .horizontal
        saveRow.alignment = .centerY
        saveRow.spacing = 8

        let saveSection = NSStackView(views: [saveCheckbox, saveRow])
        saveSection.orientation = .vertical
        saveSection.alignment = .leading
        saveSection.spacing = rowSpacing

        // Permissions rows
        let screenRecordingLabel = NSTextField(labelWithString: L("settings.permissions.screen_recording.title"))
        screenRecordingLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        screenRecordingLabel.widthAnchor.constraint(equalToConstant: leadingLabelWidth).isActive = true

        let screenRecordingRow = NSStackView(views: [
            screenRecordingLabel,
            NSView(),
            screenRecordingStatusLabel,
            screenRecordingButton
        ])
        screenRecordingRow.orientation = .horizontal
        screenRecordingRow.alignment = .centerY
        screenRecordingRow.spacing = rowSpacing

        let accessibilityLabel = NSTextField(labelWithString: L("settings.permissions.accessibility.title"))
        accessibilityLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        accessibilityLabel.widthAnchor.constraint(equalToConstant: leadingLabelWidth).isActive = true

        let accessibilityRow = NSStackView(views: [
            accessibilityLabel,
            NSView(),
            accessibilityStatusLabel,
            accessibilityButton
        ])
        accessibilityRow.orientation = .horizontal
        accessibilityRow.alignment = .centerY
        accessibilityRow.spacing = rowSpacing

        let permissionsSection = NSStackView(views: [permissionsTitleLabel, screenRecordingRow, accessibilityRow])
        permissionsSection.orientation = .vertical
        permissionsSection.alignment = .leading
        permissionsSection.spacing = sectionSpacing

        // Pro section layout
        let proButtonsRow = NSStackView(views: [upgradeButton, restoreButton, manageButton, NSView()])
        proButtonsRow.orientation = .horizontal
        proButtonsRow.alignment = .centerY
        proButtonsRow.spacing = rowSpacing
        let proSection = NSStackView(views: [proTitleLabel, proStatusLabel, proButtonsRow])
        proSection.orientation = .vertical
        proSection.alignment = .leading
        proSection.spacing = sectionSpacing

        let cleanupIntervalRow = NSStackView(views: [cleanupIntervalLabel, cleanupIntervalPopup, NSView()])
        cleanupIntervalRow.orientation = .horizontal
        cleanupIntervalRow.alignment = .centerY
        cleanupIntervalRow.spacing = rowSpacing

        let cleanupSection = NSStackView(views: [cleanupTitleLabel, cleanupToggle, cleanupIntervalRow, cleanupInfoLabel])
        cleanupSection.orientation = .vertical
        cleanupSection.alignment = .leading
        cleanupSection.spacing = sectionSpacing
        
        let divider1 = divider()
        let divider2 = divider()
        let divider3 = divider()
        let divider4 = divider()
        let divider5 = divider()
        let stack = NSStackView(views: [
            shortcutRecorder,
            divider1,
            permissionsSection,
            divider2,
            saveSection,
            divider3,
            cleanupSection,
            divider4,
            proSection,
            divider5,
            launchAtLoginCheckbox,
            versionLabel,
            NSView()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.setCustomSpacing(12, after: divider1)
        stack.setCustomSpacing(12, after: divider2)
        stack.setCustomSpacing(12, after: divider3)
        stack.setCustomSpacing(12, after: divider4)
        stack.setCustomSpacing(12, after: divider5)
        stack.setCustomSpacing(8, after: launchAtLoginCheckbox)

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: contentInset),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -contentInset),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: contentInset),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -contentInset),
        ])

        refreshSaveFolderLabel()
        refreshPermissionStatus()
        refreshProStatus()
        refreshCleanupControls()
        startProStatusObserver()
        startPermissionsObserver()
    }

    deinit {
        stopProStatusObserver()
        stopPermissionsObserver()
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

    @objc private func cleanupToggled() {
        let wantsOn = (cleanupToggle.state == .on)
        if wantsOn && !CapabilityService.shared.canUse(.libraryAutoCleanup) {
            cleanupToggle.state = .off
            PaywallWindowController.shared.show()
            refreshCleanupControls()
            return
        }

        SettingsStore.shared.autoCleanupEnabled = wantsOn
        if wantsOn && CleanupIntervalOption(rawValue: SettingsStore.shared.autoCleanupIntervalDays) == nil {
            SettingsStore.shared.autoCleanupIntervalDays = CleanupIntervalOption.default.rawValue
        }
        CleanupSchedulerService.shared.refreshSchedule()
        if wantsOn {
            _ = CleanupSchedulerService.shared.runCleanup(reason: "enable", ignoreRunGap: true)
        }
        refreshCleanupControls()
    }

    @objc private func cleanupIntervalChanged() {
        let selected = cleanupIntervalPopup.selectedTag()
        let fallback = CleanupIntervalOption.default.rawValue
        let interval = CleanupIntervalOption(rawValue: selected)?.rawValue ?? fallback

        if !CapabilityService.shared.canUse(.libraryAutoCleanup) {
            PaywallWindowController.shared.show()
            refreshCleanupControls()
            return
        }

        SettingsStore.shared.autoCleanupIntervalDays = interval
        CleanupSchedulerService.shared.refreshSchedule()
        if SettingsStore.shared.autoCleanupEnabled {
            _ = CleanupSchedulerService.shared.runCleanup(reason: "interval", ignoreRunGap: true)
        }
        refreshCleanupControls()
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

    private func versionString() -> String {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "Version \(shortVersion) (\(build))"
    }

    // MARK: - Permissions

    private func startPermissionsObserver() {
        guard permissionsObserver == nil else { return }
        permissionsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    private func stopPermissionsObserver() {
        if let permissionsObserver {
            NotificationCenter.default.removeObserver(permissionsObserver)
            self.permissionsObserver = nil
        }
    }

    private func refreshPermissionStatus() {
        let sr = ScreenRecordingGate.hasPermission()
        screenRecordingStatusLabel.stringValue = sr ? L("onboarding.status.granted") : L("onboarding.status.not_granted")

        let ax = ClipboardAutoPasteService.shared.hasAccessibilityPermission
        accessibilityStatusLabel.stringValue = ax ? L("onboarding.status.granted") : L("onboarding.status.not_granted")
    }

    @objc private func openScreenRecordingSettings() {
        PermissionsUI.openScreenRecordingSettings()
    }

    @objc private func openAccessibilitySettings() {
        PermissionsUI.openAccessibilitySettings()
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
        refreshCleanupControls()
    }

    private func refreshCleanupControls() {
        let isPro = CapabilityService.shared.canUse(.libraryAutoCleanup)
        cleanupToggle.state = SettingsStore.shared.autoCleanupEnabled ? .on : .off
        cleanupIntervalPopup.selectItem(withTag: SettingsStore.shared.autoCleanupIntervalDays)
        if cleanupIntervalPopup.selectedItem == nil {
            cleanupIntervalPopup.selectItem(withTag: CleanupIntervalOption.default.rawValue)
        }

        cleanupIntervalPopup.isEnabled = isPro && SettingsStore.shared.autoCleanupEnabled
        if isPro {
            cleanupInfoLabel.stringValue = "Auto cleanup removes expired screenshots to Trash. Kept items are always excluded."
        } else {
            cleanupInfoLabel.stringValue = "Auto cleanup is a Pro feature. Upgrade to configure interval and enable it."
        }
    }

    func focusAutoCleanupSection() {
        view.window?.makeFirstResponder(cleanupToggle)
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
