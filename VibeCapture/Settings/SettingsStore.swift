import Foundation

enum LibraryFilterMode: String {
    case all
    case kept
}

enum CleanupIntervalOption: Int, CaseIterable {
    case second5 = -5
    case second30 = -30
    case minute1 = -60
    case minute5 = -300
    case day1 = 1
    case day7 = 7
    case day15 = 15
    case day30 = 30
    case day60 = 60

    static let `default` = CleanupIntervalOption.day30

    var label: String {
        switch self {
        case .second5:
            return "5s"
        case .second30:
            return "30s"
        case .minute1:
            return "1m"
        case .minute5:
            return "5m"
        case .day1:
            return "24h"
        case .day7:
            return "7d"
        case .day15:
            return "15d"
        case .day30:
            return "30d"
        case .day60:
            return "60d"
        }
    }

    func cutoffDate(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .second5:
            return now.addingTimeInterval(-5)
        case .second30:
            return now.addingTimeInterval(-30)
        case .minute1:
            return now.addingTimeInterval(-60)
        case .minute5:
            return now.addingTimeInterval(-300)
        case .day1, .day7, .day15, .day30, .day60:
            return calendar.date(byAdding: .day, value: -rawValue, to: now) ?? now
        }
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    enum Key {
        static let captureHotKey = "captureHotKey"
        static let saveEnabled = "saveEnabled"
        static let saveFolderBookmark = "saveFolderBookmark"
        static let launchAtLogin = "launchAtLogin"
        static let libraryFilterMode = "libraryFilterMode"
        static let autoCleanupEnabled = "autoCleanupEnabled"
        static let autoCleanupIntervalDays = "autoCleanupIntervalDays"
        static let autoCleanupLastRunAt = "autoCleanupLastRunAt"
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

    var libraryFilterMode: LibraryFilterMode {
        get {
            guard
                let raw = defaults.string(forKey: Key.libraryFilterMode),
                let mode = LibraryFilterMode(rawValue: raw)
            else {
                return .all
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.libraryFilterMode)
        }
    }

    var autoCleanupEnabled: Bool {
        get {
            defaults.bool(forKey: Key.autoCleanupEnabled)
        }
        set {
            defaults.set(newValue, forKey: Key.autoCleanupEnabled)
        }
    }

    var autoCleanupIntervalDays: Int {
        get {
            let raw = defaults.integer(forKey: Key.autoCleanupIntervalDays)
            if raw == 0 {
                return CleanupIntervalOption.default.rawValue
            }
            return CleanupIntervalOption(rawValue: raw)?.rawValue ?? CleanupIntervalOption.default.rawValue
        }
        set {
            let value = CleanupIntervalOption(rawValue: newValue)?.rawValue ?? CleanupIntervalOption.default.rawValue
            defaults.set(value, forKey: Key.autoCleanupIntervalDays)
        }
    }

    var autoCleanupLastRunAt: Date? {
        get {
            let value = defaults.double(forKey: Key.autoCleanupLastRunAt)
            guard value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Key.autoCleanupLastRunAt)
            } else {
                defaults.removeObject(forKey: Key.autoCleanupLastRunAt)
            }
        }
    }
}



