import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    enum Key {
        static let captureHotKey = "captureHotKey"
        static let saveEnabled = "saveEnabled"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let launchAtLogin = "launchAtLogin"
    }

    /// Designated initializer with dependency injection support.
    /// - Parameter defaults: UserDefaults instance for storage (defaults to .standard)
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
}



