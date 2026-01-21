import AppKit

enum PermissionsUI {
    static func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = L("permission.screen_recording.title")
        alert.informativeText = L("permission.screen_recording.message")
        alert.addButton(withTitle: L("button.open_system_settings"))
        alert.addButton(withTitle: L("button.cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    static func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}



