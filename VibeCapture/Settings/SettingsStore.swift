import Foundation

/// Represents a user-added app in the send list
struct UserWhitelistApp: Codable, Equatable {
    let bundleID: String
    let displayName: String
    let appPath: String  // Path to .app for icon retrieval
}

/// Protocol for SettingsStore (enables testing/DI).
protocol SettingsStoreProtocol {
    var proUserWhitelistApps: [UserWhitelistApp] { get set }
    var freePinnedCustomApp: UserWhitelistApp? { get set }
    func userWhitelistApps(isPro: Bool) -> [UserWhitelistApp]
    func isInUserWhitelist(bundleID: String, isPro: Bool) -> Bool
    func addProUserWhitelistApp(_ app: UserWhitelistApp)
    func removeProUserWhitelistApp(bundleID: String)
}

final class SettingsStore: SettingsStoreProtocol {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    enum Key {
        static let captureHotKey = "captureHotKey"
        static let saveEnabled = "saveEnabled"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let launchAtLogin = "launchAtLogin"
        // Legacy (pre-IAP): all user-added apps lived here
        static let userWhitelistAppsLegacy = "userWhitelistApps"

        // IAP: split storage
        static let proUserWhitelistApps = "proUserWhitelistApps"
        static let freePinnedCustomApp = "freePinnedCustomApp"
        static let didMigrateWhitelistApps = "didMigrateUserWhitelistAppsToPro"
    }

    /// Designated initializer with dependency injection support.
    /// - Parameter defaults: UserDefaults instance for storage (defaults to .standard)
    /// - Parameter skipMigration: If true, skip legacy migration (useful for testing)
    init(defaults: UserDefaults = .standard, skipMigration: Bool = false) {
        self.defaults = defaults
        if !skipMigration {
            migrateLegacyWhitelistIfNeeded()
        }
    }

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
    
    // MARK: - IAP Whitelist Storage

    var proUserWhitelistApps: [UserWhitelistApp] {
        get {
            guard let data = defaults.data(forKey: Key.proUserWhitelistApps),
                  let apps = try? JSONDecoder().decode([UserWhitelistApp].self, from: data) else {
                return []
            }
            return apps
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: Key.proUserWhitelistApps)
        }
    }

    var freePinnedCustomApp: UserWhitelistApp? {
        get {
            guard let data = defaults.data(forKey: Key.freePinnedCustomApp),
                  let app = try? JSONDecoder().decode(UserWhitelistApp.self, from: data) else {
                return nil
            }
            return app
        }
        set {
            if let newValue {
                let data = try? JSONEncoder().encode(newValue)
                defaults.set(data, forKey: Key.freePinnedCustomApp)
            } else {
                defaults.removeObject(forKey: Key.freePinnedCustomApp)
            }
        }
    }

    /// Returns the effective user-added whitelist apps based on Free/Pro tier.
    /// - Pro: pro list + (pinned if exists)
    /// - Free: pinned only (may be nil)
    func userWhitelistApps(isPro: Bool) -> [UserWhitelistApp] {
        if isPro {
            var apps = proUserWhitelistApps
            if let pinned = freePinnedCustomApp, !apps.contains(where: { $0.bundleID == pinned.bundleID }) {
                apps.append(pinned)
            }
            return apps
        } else {
            return freePinnedCustomApp.map { [$0] } ?? []
        }
    }

    func isInUserWhitelist(bundleID: String, isPro: Bool) -> Bool {
        userWhitelistApps(isPro: isPro).contains { $0.bundleID == bundleID }
    }

    /// Pro-only: add to manageable list (ignores duplicates).
    func addProUserWhitelistApp(_ app: UserWhitelistApp) {
        var apps = proUserWhitelistApps
        if !apps.contains(where: { $0.bundleID == app.bundleID }) {
            apps.append(app)
            proUserWhitelistApps = apps
        }
    }

    /// Pro-only: remove from manageable list.
    func removeProUserWhitelistApp(bundleID: String) {
        var apps = proUserWhitelistApps
        apps.removeAll { $0.bundleID == bundleID }
        proUserWhitelistApps = apps
    }

    // MARK: - Migration

    private func migrateLegacyWhitelistIfNeeded() {
        if defaults.bool(forKey: Key.didMigrateWhitelistApps) {
            return
        }

        guard let data = defaults.data(forKey: Key.userWhitelistAppsLegacy),
              let legacy = try? JSONDecoder().decode([UserWhitelistApp].self, from: data),
              !legacy.isEmpty
        else {
            defaults.set(true, forKey: Key.didMigrateWhitelistApps)
            return
        }

        // Only write if pro list is empty to avoid overwriting.
        if proUserWhitelistApps.isEmpty {
            proUserWhitelistApps = legacy
        }

        // Keep legacy key for backwards compatibility with older builds, but mark migrated.
        defaults.set(true, forKey: Key.didMigrateWhitelistApps)
    }
}



