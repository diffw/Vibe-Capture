import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let captureHotKey = "captureHotKey"
        static let saveEnabled = "saveEnabled"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let launchAtLogin = "launchAtLogin"
        static let screenshotSavePath = "screenshotSavePath"
        static let screenshotSavePathBookmark = "screenshotSavePathBookmark"
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

    /// Screenshot save path (display path for UI)
    var screenshotSavePath: String? {
        get { defaults.string(forKey: Key.screenshotSavePath) }
        set { defaults.set(newValue, forKey: Key.screenshotSavePath) }
    }

    /// Security-scoped bookmark for screenshot save path
    var screenshotSavePathBookmark: Data? {
        get { defaults.data(forKey: Key.screenshotSavePathBookmark) }
        set { defaults.set(newValue, forKey: Key.screenshotSavePathBookmark) }
    }

    /// Check if a screenshot save path has been configured
    var hasScreenshotSavePath: Bool {
        screenshotSavePathBookmark != nil
    }

    /// Clear the screenshot save path
    func clearScreenshotSavePath() {
        screenshotSavePath = nil
        screenshotSavePathBookmark = nil
    }
}



