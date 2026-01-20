import Foundation

/// Represents a user-added app in the send list
struct UserWhitelistApp: Codable, Equatable {
    let bundleID: String
    let displayName: String
    let appPath: String  // Path to .app for icon retrieval
}

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let captureHotKey = "captureHotKey"
        static let saveEnabled = "saveEnabled"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let launchAtLogin = "launchAtLogin"
        static let userWhitelistApps = "userWhitelistApps"
    }

    private init() {}

    var captureHotKey: KeyCombo {
        get {
            guard
                let data = defaults.data(forKey: Key.captureHotKey),
                let combo = try? JSONDecoder().decode(KeyCombo.self, from: data)
            else {
                return .defaultCapture
            }
            return combo
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: Key.captureHotKey)
        }
    }

    var saveEnabled: Bool {
        get {
            if defaults.object(forKey: Key.saveEnabled) == nil {
                return true // default ON
            }
            return defaults.bool(forKey: Key.saveEnabled)
        }
        set { defaults.set(newValue, forKey: Key.saveEnabled) }
    }

    var saveFolderBookmark: Data? {
        get { defaults.data(forKey: Key.saveFolderBookmark) }
        set { defaults.set(newValue, forKey: Key.saveFolderBookmark) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }
    
    // MARK: - User Whitelist Apps
    
    /// List of user-added apps to the send list
    var userWhitelistApps: [UserWhitelistApp] {
        get {
            guard let data = defaults.data(forKey: Key.userWhitelistApps),
                  let apps = try? JSONDecoder().decode([UserWhitelistApp].self, from: data) else {
                return []
            }
            return apps
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: Key.userWhitelistApps)
        }
    }
    
    /// Add an app to the user whitelist
    func addUserWhitelistApp(_ app: UserWhitelistApp) {
        var apps = userWhitelistApps
        // Avoid duplicates
        if !apps.contains(where: { $0.bundleID == app.bundleID }) {
            apps.append(app)
            userWhitelistApps = apps
        }
    }
    
    /// Remove an app from the user whitelist
    func removeUserWhitelistApp(bundleID: String) {
        var apps = userWhitelistApps
        apps.removeAll { $0.bundleID == bundleID }
        userWhitelistApps = apps
    }
    
    /// Check if an app is in the user whitelist
    func isInUserWhitelist(bundleID: String) -> Bool {
        userWhitelistApps.contains { $0.bundleID == bundleID }
    }
}



