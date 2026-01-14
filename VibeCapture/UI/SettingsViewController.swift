import AppKit

final class SettingsViewController: NSViewController {
    private let shortcutRecorder = ShortcutRecorderView()

    private let saveCheckbox = NSButton(checkboxWithTitle: "Save screenshots after Copy", target: nil, action: nil)
    private let saveFolderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "Choose Folder…", target: nil, action: nil)

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        shortcutRecorder.onChange = { [weak self] combo in
            self?.applyShortcut(combo)
        }

        saveCheckbox.target = self
        saveCheckbox.action = #selector(saveToggled)
        saveCheckbox.state = SettingsStore.shared.saveEnabled ? .on : .off

        saveFolderLabel.textColor = .secondaryLabelColor
        saveFolderLabel.font = NSFont.systemFont(ofSize: 12)
        saveFolderLabel.lineBreakMode = .byTruncatingMiddle

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolderPressed)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginToggled)
        launchAtLoginCheckbox.state = LaunchAtLoginService.shared.isEnabled ? .on : .off

        let saveRow = NSStackView(views: [chooseFolderButton, NSView(), saveFolderLabel])
        saveRow.orientation = .horizontal
        saveRow.alignment = .centerY
        saveRow.spacing = 8

        let saveSection = NSStackView(views: [saveCheckbox, saveRow])
        saveSection.orientation = .vertical
        saveSection.spacing = 6

        let stack = NSStackView(views: [shortcutRecorder, divider(), saveSection, divider(), launchAtLoginCheckbox, NSView()])
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
            showError(title: "Shortcut Unavailable", message: error.localizedDescription)
        }
    }

    @objc private func saveToggled() {
        SettingsStore.shared.saveEnabled = (saveCheckbox.state == .on)
        refreshSaveFolderLabel()
    }

    @objc private func chooseFolderPressed() {
        do {
            if let url = try ScreenshotSaveService.shared.chooseAndStoreFolder() {
                HUDService.shared.show(message: "Folder Selected", style: .success)
                saveFolderLabel.stringValue = url.path
            }
        } catch {
            showError(title: "Unable to Set Folder", message: error.localizedDescription)
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
            showError(title: "Launch at Login Failed", message: error.localizedDescription)
        }
    }

    private func showLaunchApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = "Approval Required"
        alert.informativeText = "To launch Vibe Capture at login, enable it in System Settings → General → Login Items."
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "OK")
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            LaunchAtLoginService.openLoginItemsSettings()
        }
    }

    private func refreshSaveFolderLabel() {
        if !SettingsStore.shared.saveEnabled {
            saveFolderLabel.stringValue = "Saving disabled"
            return
        }
        if let url = ScreenshotSaveService.shared.currentFolderURL() {
            saveFolderLabel.stringValue = url.path
        } else {
            saveFolderLabel.stringValue = "No folder selected (you’ll be asked on first save)"
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}



