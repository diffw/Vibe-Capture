import Foundation
@testable import VibeCap

/// Mock implementation of SettingsStoreProtocol for unit testing.
final class MockSettingsStore: SettingsStoreProtocol {
    
    // MARK: - Protocol Properties
    
    var proUserWhitelistApps: [UserWhitelistApp] = []
    var freePinnedCustomApp: UserWhitelistApp?
    
    // MARK: - Test Helpers
    
    /// Track method calls for verification.
    private(set) var addAppCallCount = 0
    private(set) var removeAppCallCount = 0
    private(set) var lastAddedApp: UserWhitelistApp?
    private(set) var lastRemovedBundleID: String?
    
    // MARK: - Protocol Methods
    
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
    
    func addProUserWhitelistApp(_ app: UserWhitelistApp) {
        addAppCallCount += 1
        lastAddedApp = app
        
        if !proUserWhitelistApps.contains(where: { $0.bundleID == app.bundleID }) {
            proUserWhitelistApps.append(app)
        }
    }
    
    func removeProUserWhitelistApp(bundleID: String) {
        removeAppCallCount += 1
        lastRemovedBundleID = bundleID
        
        proUserWhitelistApps.removeAll { $0.bundleID == bundleID }
    }
    
    // MARK: - Convenience Methods for Testing
    
    /// Create a test UserWhitelistApp with given parameters.
    static func makeTestApp(
        bundleID: String = "com.test.app",
        displayName: String = "Test App",
        appPath: String = "/Applications/Test.app"
    ) -> UserWhitelistApp {
        UserWhitelistApp(bundleID: bundleID, displayName: displayName, appPath: appPath)
    }
    
    /// Reset all test state.
    func reset() {
        proUserWhitelistApps = []
        freePinnedCustomApp = nil
        addAppCallCount = 0
        removeAppCallCount = 0
        lastAddedApp = nil
        lastRemovedBundleID = nil
    }
}
