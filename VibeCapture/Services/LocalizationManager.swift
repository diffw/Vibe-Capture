//
//  LocalizationManager.swift
//  VibeCapture
//
//  Manages app localization: system language detection, in-app override, and string loading.
//

import Foundation

// MARK: - Global Localization Helper

/// Shorthand for localized string lookup.
/// Usage: L("menu.capture_area") or L("modal.button.send_to_app", appName)
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.shared.localizedString(forKey: key)
    if args.isEmpty {
        return format
    }
    return String(format: format, arguments: args)
}

// MARK: - LocalizationManager

final class LocalizationManager {
    
    static let shared = LocalizationManager()
    
    // MARK: - Supported Languages
    
    /// All supported language codes (Apple standard .lproj names)
    static let supportedLanguages: [(code: String, displayName: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("es", "Español"),
        ("ko", "한국어"),
        ("it", "Italiano"),
        ("sv", "Svenska"),
    ]
    
    // MARK: - UserDefaults Key
    
    private static let languageOverrideKey = "AppLanguageOverride"
    
    // MARK: - Properties
    
    /// Current active language code
    private(set) var currentLanguage: String
    
    /// Loaded string bundle for current language
    private var bundle: Bundle
    
    /// Cache of loaded strings (for performance)
    private var stringCache: [String: String] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Determine initial language
        let language = LocalizationManager.resolveLanguage()
        self.currentLanguage = language
        self.bundle = LocalizationManager.loadBundle(for: language)
    }
    
    // MARK: - Language Resolution
    
    /// Resolves which language to use: override > system > fallback
    private static func resolveLanguage() -> String {
        // 1. Check for user override
        if let override = UserDefaults.standard.string(forKey: languageOverrideKey),
           supportedLanguages.contains(where: { $0.code == override }) {
            return override
        }
        
        // 2. Check system preferred languages
        for preferredLang in Locale.preferredLanguages {
            // Extract base language code (e.g., "zh-Hans-CN" -> "zh-Hans", "en-US" -> "en")
            let normalized = normalizeLanguageCode(preferredLang)
            if supportedLanguages.contains(where: { $0.code == normalized }) {
                return normalized
            }
        }
        
        // 3. Fallback to English
        return "en"
    }
    
    /// Normalizes a language code to match our .lproj naming
    private static func normalizeLanguageCode(_ code: String) -> String {
        // Handle Chinese variants
        if code.hasPrefix("zh-Hans") || code.hasPrefix("zh-CN") || code == "zh" {
            return "zh-Hans"
        }
        if code.hasPrefix("zh-Hant") || code.hasPrefix("zh-TW") || code.hasPrefix("zh-HK") {
            return "zh-Hant"
        }
        
        // Handle Norwegian (nb = Bokmål, no = generic Norwegian)
        if code.hasPrefix("nb") || code.hasPrefix("no") {
            return "nb"
        }
        
        // Extract base language for others (e.g., "en-US" -> "en")
        let components = code.split(separator: "-")
        if let base = components.first {
            return String(base)
        }
        
        return code
    }
    
    // MARK: - Bundle Loading
    
    /// Loads the bundle for a specific language
    private static func loadBundle(for language: String) -> Bundle {
        // Try to find the .lproj folder in the standard bundle location.
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Xcode folder-reference fallback:
        // In this repo, `VibeCapture/Resources` is sometimes added to Xcode as a *folder reference*,
        // which gets copied into the app bundle as a subfolder named "Resources".
        // That places localizations at "Resources/<lang>.lproj/Localizable.strings".
        if let path = Bundle.main.path(forResource: language, ofType: "lproj", inDirectory: "Resources"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        
        // Fallback to main bundle (will use en.lproj or Base.lproj)
        print("[Localization] Warning: Could not load bundle for \(language), falling back to main bundle")
        return Bundle.main
    }
    
    // MARK: - String Lookup
    
    /// Returns the localized string for a key
    func localizedString(forKey key: String) -> String {
        // Check cache first
        if let cached = stringCache[key] {
            return cached
        }
        
        // Look up in bundle
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        
        // If key not found (returns key itself), try English fallback
        if value == key && currentLanguage != "en" {
            let enBundle = LocalizationManager.loadBundle(for: "en")
            let fallback = enBundle.localizedString(forKey: key, value: nil, table: "Localizable")
            if fallback != key {
                stringCache[key] = fallback
                return fallback
            }
        }
        
        // Cache and return
        stringCache[key] = value
        return value
    }
    
    // MARK: - Language Switching

    /// Sets the app language override. Requires app restart to take effect.
    /// Pass nil to clear override and use system language.
    func setLanguageOverride(_ languageCode: String?) {
        if let code = languageCode {
            guard Self.supportedLanguages.contains(where: { $0.code == code }) else {
                print("[Localization] Warning: Unsupported language code: \(code)")
                return
            }
            UserDefaults.standard.set(code, forKey: Self.languageOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.languageOverrideKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Get a localized string for a specific language (used for showing alerts in the new language)
    func localizedString(forKey key: String, language: String) -> String {
        let bundle = Self.loadBundle(for: language)
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        
        // Fallback to English if key not found
        if value == key && language != "en" {
            let enBundle = Self.loadBundle(for: "en")
            return enBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return value
    }
    
    /// Get the effective language after a potential override is set
    /// (before app restart, to show alerts in the new language)
    func getEffectiveLanguage() -> String {
        if let override = getLanguageOverride() {
            return override
        }
        return Self.resolveLanguage()
    }
    
    /// Returns the current language override, or nil if using system language
    func getLanguageOverride() -> String? {
        return UserDefaults.standard.string(forKey: Self.languageOverrideKey)
    }
    
    /// Checks if the current language is system-determined (no override)
    var isUsingSystemLanguage: Bool {
        return getLanguageOverride() == nil
    }
    
    /// Reloads strings for a new language (used after setLanguageOverride + restart)
    func reload() {
        let language = Self.resolveLanguage()
        self.currentLanguage = language
        self.bundle = Self.loadBundle(for: language)
        self.stringCache.removeAll()
    }
}
