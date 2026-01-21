import AppKit
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
    case requiresApproval

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return L("error.launch_login_requires_approval")
        }
    }
}

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    private init() {}

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            if SMAppService.mainApp.status == .requiresApproval {
                throw LaunchAtLoginError.requiresApproval
            }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        // Best-effort deep link (works on recent macOS versions); otherwise open System Settings.
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}



