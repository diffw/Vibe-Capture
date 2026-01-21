import AppKit

/// Represents a target application for pasting
struct TargetApp: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let icon: NSImage?
    let runningApp: NSRunningApplication?
    
    var isRunning: Bool {
        runningApp != nil
    }
}

/// Service that detects and tracks active applications
final class AppDetectionService {
    static let shared = AppDetectionService()
    
    /// Whitelist of optimized applications (Bundle ID -> Display Name)
    /// These apps have custom timing/focus configurations for best experience
    private let whitelistApps: [(bundleID: String, displayName: String)] = [
        // AI Code Editors
        ("com.todesktop.230313mzl4w4u92", "Cursor"),
        ("com.cursor.Cursor", "Cursor"),
        ("com.microsoft.VSCode", "VS Code"),
        ("com.exafunction.windsurf", "Windsurf"),
        ("com.google.antigravity", "Antigravity"),
        // Design & Chat
        ("com.figma.Desktop", "Figma"),
        ("ru.keepcoder.Telegram", "Telegram"),
        ("org.telegram.desktop", "Telegram"),
        ("com.anthropic.claudefordesktop", "Claude"),
        // Notes
        ("md.obsidian", "Obsidian"),
        // Browsers (for web apps like ChatGPT, Gemini, Claude Web)
        ("com.google.Chrome", "Chrome"),
        ("com.apple.Safari", "Safari"),
        ("com.microsoft.edgemac", "Edge"),
        ("company.thebrowser.Browser", "Arc"),
    ]
    
    /// Blacklist of apps that don't support image paste
    /// These apps will show "Save Image" instead of "Send to [App]"
    private let blacklistApps: [String] = [
        // System core
        "com.apple.finder",                    // Finder
        "com.apple.systempreferences",         // System Preferences (older)
        "com.apple.Preferences",               // System Settings (newer)
        "com.apple.Preview",                   // Preview
        "com.apple.ActivityMonitor",           // Activity Monitor
        "com.apple.Terminal",                  // Terminal
        "com.apple.dt.Xcode",                  // Xcode
        // Utilities
        "com.apple.AppStore",                  // App Store
        "com.apple.Passwords",                 // Passwords
        "com.apple.calculator",                // Calculator
        "com.apple.clock",                     // Clock
        "com.apple.findmy",                    // Find My
        "com.apple.Home",                      // Home
        "com.apple.Magnifier",                 // Magnifier
        "com.apple.TestFlight",                // TestFlight
        "com.apple.VoiceMemos",                // Voice Memos
        "com.apple.Console",                   // Console
        "com.apple.Dictionary",                // Dictionary
        "com.apple.airport.airportutility",    // AirPort Utility
        "com.apple.Automator",                 // Automator
        "com.apple.BluetoothFileExchange",     // Bluetooth File Exchange
        "com.apple.ColorSyncUtility",          // ColorSync Utility
        "com.apple.DiskUtility",               // Disk Utility
        "com.apple.grapher",                   // Grapher
        "com.apple.print.PrinterProxy",        // Print Center
        "com.apple.ScreenSharing",             // Screen Sharing
        "com.apple.Screenshot",                // Screenshot
    ]
    
    /// Track the previous frontmost application (before our app became active)
    private var previousFrontmostApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?
    
    private init() {
        setupWorkspaceObserver()
    }
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    /// Get the target app to paste to (previous app if we're frontmost, otherwise current)
    func getTargetApp() -> TargetApp? {
        let currentApp = NSWorkspace.shared.frontmostApplication
        
        // If we're the frontmost app, return the previous app
        if currentApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return previousFrontmostApp.flatMap { makeTargetApp(from: $0) }
        }
        
        // Otherwise return the current frontmost app
        return currentApp.flatMap { makeTargetApp(from: $0) }
    }
    
    /// Check if the given app is in our whitelist (official or user-added)
    func isWhitelisted(_ app: TargetApp) -> Bool {
        return isWhitelisted(bundleID: app.bundleIdentifier)
    }
    
    /// Check if the given bundle identifier is in our whitelist (official or user-added)
    func isWhitelisted(bundleID: String) -> Bool {
        return isOfficialWhitelisted(bundleID: bundleID) || 
               SettingsStore.shared.isInUserWhitelist(bundleID: bundleID)
    }
    
    /// Check if the given bundle identifier is in the official whitelist only
    func isOfficialWhitelisted(bundleID: String) -> Bool {
        return whitelistApps.contains { $0.bundleID == bundleID }
    }
    
    /// Check if the given app is blacklisted (doesn't support image paste)
    func isBlacklisted(_ app: TargetApp) -> Bool {
        return blacklistApps.contains { $0.lowercased() == app.bundleIdentifier.lowercased() }
    }
    
    /// Check if the given bundle identifier is blacklisted
    func isBlacklisted(bundleID: String) -> Bool {
        return blacklistApps.contains { $0.lowercased() == bundleID.lowercased() }
    }
    
    /// Get all running whitelisted apps (official + user-added)
    func getRunningWhitelistedApps() -> [TargetApp] {
        var result: [TargetApp] = []
        var seenBundleIDs: Set<String> = []
        
        // 1. Add official whitelist apps
        for (bundleID, displayName) in whitelistApps {
            guard !seenBundleIDs.contains(bundleID) else { continue }
            
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                let icon = runningApp.icon ?? NSWorkspace.shared.icon(forFile: runningApp.bundleURL?.path ?? "")
                result.append(TargetApp(
                    bundleIdentifier: bundleID,
                    displayName: displayName,
                    icon: icon,
                    runningApp: runningApp
                ))
                seenBundleIDs.insert(bundleID)
            }
        }
        
        // 2. Add user whitelist apps
        for userApp in SettingsStore.shared.userWhitelistApps {
            guard !seenBundleIDs.contains(userApp.bundleID) else { continue }
            
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: userApp.bundleID).first {
                let icon = runningApp.icon ?? NSWorkspace.shared.icon(forFile: userApp.appPath)
                result.append(TargetApp(
                    bundleIdentifier: userApp.bundleID,
                    displayName: userApp.displayName,
                    icon: icon,
                    runningApp: runningApp
                ))
                seenBundleIDs.insert(userApp.bundleID)
            }
        }
        
        return result
    }
    
    /// Get all running regular apps (for the Add to Send List panel)
    /// Excludes our own app and background processes
    func getAllRunningApps() -> [TargetApp] {
        var result: [TargetApp] = []
        var seenBundleIDs: Set<String> = []
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular &&
            app.bundleIdentifier != nil &&
            app.bundleIdentifier != ownBundleID
        }
        
        for runningApp in runningApps {
            guard let bundleID = runningApp.bundleIdentifier else { continue }
            guard !seenBundleIDs.contains(bundleID) else { continue }
            seenBundleIDs.insert(bundleID)
            
            result.append(makeTargetApp(from: runningApp))
        }
        
        // Sort alphabetically
        result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
        return result
    }
    
    /// Activate a target app
    /// Always re-fetch the running app instance to ensure we use the latest reference
    func activate(_ app: TargetApp) -> Bool {
        // Always re-fetch the running app instance (don't use stale reference)
        if let freshApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            freshApp.activate(options: [.activateIgnoringOtherApps])
            return true
        }
        return false
    }
    
    /// Manually record the current frontmost app as previous (call before showing our UI)
    func recordCurrentAppAsPrevious() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontmostApp = app
        }
    }
    
    // MARK: - Private
    
    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            // When another app becomes active, record it as previous
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.previousFrontmostApp = app
            }
        }
    }
    
    private func makeTargetApp(from runningApp: NSRunningApplication) -> TargetApp {
        let bundleID = runningApp.bundleIdentifier ?? ""
        
        // Check if it's a whitelisted app to get the proper display name
        let displayName: String
        if let whitelistEntry = whitelistApps.first(where: { $0.bundleID == bundleID }) {
            // Official whitelist
            displayName = whitelistEntry.displayName
        } else if let userEntry = SettingsStore.shared.userWhitelistApps.first(where: { $0.bundleID == bundleID }) {
            // User whitelist
            displayName = userEntry.displayName
        } else {
            displayName = runningApp.localizedName ?? L("app.unknown")
        }
        
        let icon = runningApp.icon ?? NSWorkspace.shared.icon(forFile: runningApp.bundleURL?.path ?? "")
        
        return TargetApp(
            bundleIdentifier: bundleID,
            displayName: displayName,
            icon: icon,
            runningApp: runningApp
        )
    }
}
