import XCTest
@testable import VibeCapture

/// Unit tests for SettingsStore.
final class SettingsStoreTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    private var sut: SettingsStore!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.test.settings.\(UUID().uuidString)")!
        testDefaults.removePersistentDomain(forName: testDefaults.suiteName!)
        sut = SettingsStore(defaults: testDefaults, skipMigration: true)
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.suiteName!)
        testDefaults = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Helper
    
    private func makeTestApp(bundleID: String = "com.test.app", name: String = "Test App") -> UserWhitelistApp {
        UserWhitelistApp(bundleID: bundleID, displayName: name, appPath: "/Applications/\(name).app")
    }
    
    // MARK: - Pro Whitelist Apps Tests
    
    func testProUserWhitelistAppsInitiallyEmpty() {
        XCTAssertTrue(sut.proUserWhitelistApps.isEmpty)
    }
    
    func testAddProUserWhitelistApp() {
        let app = makeTestApp()
        
        sut.addProUserWhitelistApp(app)
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 1)
        XCTAssertEqual(sut.proUserWhitelistApps.first?.bundleID, app.bundleID)
    }
    
    func testAddMultipleProUserWhitelistApps() {
        let app1 = makeTestApp(bundleID: "com.test.app1", name: "App 1")
        let app2 = makeTestApp(bundleID: "com.test.app2", name: "App 2")
        let app3 = makeTestApp(bundleID: "com.test.app3", name: "App 3")
        
        sut.addProUserWhitelistApp(app1)
        sut.addProUserWhitelistApp(app2)
        sut.addProUserWhitelistApp(app3)
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 3)
    }
    
    func testAddDuplicateProUserWhitelistAppIgnored() {
        let app = makeTestApp()
        
        sut.addProUserWhitelistApp(app)
        sut.addProUserWhitelistApp(app)
        sut.addProUserWhitelistApp(app)
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 1)
    }
    
    func testAddDuplicateBundleIDWithDifferentNameIgnored() {
        let app1 = makeTestApp(bundleID: "com.test.app", name: "App Name 1")
        let app2 = makeTestApp(bundleID: "com.test.app", name: "App Name 2")
        
        sut.addProUserWhitelistApp(app1)
        sut.addProUserWhitelistApp(app2)
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 1)
        XCTAssertEqual(sut.proUserWhitelistApps.first?.displayName, "App Name 1")
    }
    
    func testRemoveProUserWhitelistApp() {
        let app = makeTestApp()
        sut.addProUserWhitelistApp(app)
        
        sut.removeProUserWhitelistApp(bundleID: app.bundleID)
        
        XCTAssertTrue(sut.proUserWhitelistApps.isEmpty)
    }
    
    func testRemoveNonexistentProUserWhitelistAppDoesNothing() {
        let app = makeTestApp(bundleID: "com.test.app1")
        sut.addProUserWhitelistApp(app)
        
        sut.removeProUserWhitelistApp(bundleID: "com.test.nonexistent")
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 1)
    }
    
    func testRemoveFromMultipleProUserWhitelistApps() {
        let app1 = makeTestApp(bundleID: "com.test.app1", name: "App 1")
        let app2 = makeTestApp(bundleID: "com.test.app2", name: "App 2")
        let app3 = makeTestApp(bundleID: "com.test.app3", name: "App 3")
        
        sut.addProUserWhitelistApp(app1)
        sut.addProUserWhitelistApp(app2)
        sut.addProUserWhitelistApp(app3)
        
        sut.removeProUserWhitelistApp(bundleID: "com.test.app2")
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 2)
        XCTAssertFalse(sut.proUserWhitelistApps.contains(where: { $0.bundleID == "com.test.app2" }))
    }
    
    // MARK: - Free Pinned Custom App Tests
    
    func testFreePinnedCustomAppInitiallyNil() {
        XCTAssertNil(sut.freePinnedCustomApp)
    }
    
    func testSetFreePinnedCustomApp() {
        let app = makeTestApp()
        
        sut.freePinnedCustomApp = app
        
        XCTAssertNotNil(sut.freePinnedCustomApp)
        XCTAssertEqual(sut.freePinnedCustomApp?.bundleID, app.bundleID)
    }
    
    func testClearFreePinnedCustomApp() {
        let app = makeTestApp()
        sut.freePinnedCustomApp = app
        
        sut.freePinnedCustomApp = nil
        
        XCTAssertNil(sut.freePinnedCustomApp)
    }
    
    func testReplaceFreePinnedCustomApp() {
        let app1 = makeTestApp(bundleID: "com.test.app1", name: "App 1")
        let app2 = makeTestApp(bundleID: "com.test.app2", name: "App 2")
        
        sut.freePinnedCustomApp = app1
        sut.freePinnedCustomApp = app2
        
        XCTAssertEqual(sut.freePinnedCustomApp?.bundleID, "com.test.app2")
    }
    
    // MARK: - userWhitelistApps(isPro:) Tests
    
    func testUserWhitelistAppsProModeReturnsProList() {
        let app1 = makeTestApp(bundleID: "com.test.app1")
        let app2 = makeTestApp(bundleID: "com.test.app2")
        sut.addProUserWhitelistApp(app1)
        sut.addProUserWhitelistApp(app2)
        
        let apps = sut.userWhitelistApps(isPro: true)
        
        XCTAssertEqual(apps.count, 2)
    }
    
    func testUserWhitelistAppsProModeIncludesPinnedApp() {
        let proApp = makeTestApp(bundleID: "com.test.proapp")
        let pinnedApp = makeTestApp(bundleID: "com.test.pinnedapp")
        sut.addProUserWhitelistApp(proApp)
        sut.freePinnedCustomApp = pinnedApp
        
        let apps = sut.userWhitelistApps(isPro: true)
        
        XCTAssertEqual(apps.count, 2)
        XCTAssertTrue(apps.contains(where: { $0.bundleID == "com.test.proapp" }))
        XCTAssertTrue(apps.contains(where: { $0.bundleID == "com.test.pinnedapp" }))
    }
    
    func testUserWhitelistAppsProModeDeduplicatesPinnedApp() {
        let app = makeTestApp(bundleID: "com.test.app")
        sut.addProUserWhitelistApp(app)
        sut.freePinnedCustomApp = app  // Same app pinned
        
        let apps = sut.userWhitelistApps(isPro: true)
        
        XCTAssertEqual(apps.count, 1)  // Should not duplicate
    }
    
    func testUserWhitelistAppsFreeModeReturnsPinnedOnly() {
        let proApp = makeTestApp(bundleID: "com.test.proapp")
        let pinnedApp = makeTestApp(bundleID: "com.test.pinnedapp")
        sut.addProUserWhitelistApp(proApp)
        sut.freePinnedCustomApp = pinnedApp
        
        let apps = sut.userWhitelistApps(isPro: false)
        
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.bundleID, "com.test.pinnedapp")
    }
    
    func testUserWhitelistAppsFreeModeReturnsEmptyWhenNoPinned() {
        let proApp = makeTestApp(bundleID: "com.test.proapp")
        sut.addProUserWhitelistApp(proApp)
        
        let apps = sut.userWhitelistApps(isPro: false)
        
        XCTAssertTrue(apps.isEmpty)
    }
    
    // MARK: - isInUserWhitelist Tests
    
    func testIsInUserWhitelistProModeFindsBundleID() {
        let app = makeTestApp(bundleID: "com.test.app")
        sut.addProUserWhitelistApp(app)
        
        XCTAssertTrue(sut.isInUserWhitelist(bundleID: "com.test.app", isPro: true))
    }
    
    func testIsInUserWhitelistProModeReturnsFalseForMissing() {
        XCTAssertFalse(sut.isInUserWhitelist(bundleID: "com.test.nonexistent", isPro: true))
    }
    
    func testIsInUserWhitelistFreeModeFindsPinnedApp() {
        let pinnedApp = makeTestApp(bundleID: "com.test.pinnedapp")
        sut.freePinnedCustomApp = pinnedApp
        
        XCTAssertTrue(sut.isInUserWhitelist(bundleID: "com.test.pinnedapp", isPro: false))
    }
    
    func testIsInUserWhitelistFreeModeDoesNotFindProApp() {
        let proApp = makeTestApp(bundleID: "com.test.proapp")
        sut.addProUserWhitelistApp(proApp)
        
        XCTAssertFalse(sut.isInUserWhitelist(bundleID: "com.test.proapp", isPro: false))
    }
    
    // MARK: - Persistence Tests
    
    func testProUserWhitelistAppsPersistedToDefaults() {
        let app = makeTestApp()
        sut.addProUserWhitelistApp(app)
        
        // Create new instance with same defaults
        let newStore = SettingsStore(defaults: testDefaults, skipMigration: true)
        
        XCTAssertEqual(newStore.proUserWhitelistApps.count, 1)
        XCTAssertEqual(newStore.proUserWhitelistApps.first?.bundleID, app.bundleID)
    }
    
    func testFreePinnedCustomAppPersistedToDefaults() {
        let app = makeTestApp()
        sut.freePinnedCustomApp = app
        
        // Create new instance with same defaults
        let newStore = SettingsStore(defaults: testDefaults, skipMigration: true)
        
        XCTAssertNotNil(newStore.freePinnedCustomApp)
        XCTAssertEqual(newStore.freePinnedCustomApp?.bundleID, app.bundleID)
    }
    
    func testClearedFreePinnedCustomAppPersistedToDefaults() {
        let app = makeTestApp()
        sut.freePinnedCustomApp = app
        sut.freePinnedCustomApp = nil
        
        // Create new instance with same defaults
        let newStore = SettingsStore(defaults: testDefaults, skipMigration: true)
        
        XCTAssertNil(newStore.freePinnedCustomApp)
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromLegacyWhitelistApps() {
        // Set up legacy data
        let legacyApps = [
            makeTestApp(bundleID: "com.legacy.app1"),
            makeTestApp(bundleID: "com.legacy.app2")
        ]
        let legacyData = try! JSONEncoder().encode(legacyApps)
        testDefaults.set(legacyData, forKey: SettingsStore.Key.userWhitelistAppsLegacy)
        
        // Create store WITHOUT skipping migration
        let migratingStore = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        XCTAssertEqual(migratingStore.proUserWhitelistApps.count, 2)
        XCTAssertTrue(migratingStore.proUserWhitelistApps.contains(where: { $0.bundleID == "com.legacy.app1" }))
        XCTAssertTrue(migratingStore.proUserWhitelistApps.contains(where: { $0.bundleID == "com.legacy.app2" }))
    }
    
    func testMigrationDoesNotOverwriteExistingProApps() {
        // Set up existing pro apps
        let existingApp = makeTestApp(bundleID: "com.existing.app")
        sut.addProUserWhitelistApp(existingApp)
        
        // Set up legacy data
        let legacyApps = [makeTestApp(bundleID: "com.legacy.app")]
        let legacyData = try! JSONEncoder().encode(legacyApps)
        testDefaults.set(legacyData, forKey: SettingsStore.Key.userWhitelistAppsLegacy)
        
        // Reset migration flag
        testDefaults.removeObject(forKey: SettingsStore.Key.didMigrateWhitelistApps)
        
        // Create store WITH migration
        let migratingStore = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        // Should keep existing app, not overwrite with legacy
        XCTAssertEqual(migratingStore.proUserWhitelistApps.count, 1)
        XCTAssertEqual(migratingStore.proUserWhitelistApps.first?.bundleID, "com.existing.app")
    }
    
    func testMigrationOnlyRunsOnce() {
        // Set up legacy data
        let legacyApps = [makeTestApp(bundleID: "com.legacy.app")]
        let legacyData = try! JSONEncoder().encode(legacyApps)
        testDefaults.set(legacyData, forKey: SettingsStore.Key.userWhitelistAppsLegacy)
        
        // First migration
        let _ = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        // Clear pro apps
        testDefaults.removeObject(forKey: SettingsStore.Key.proUserWhitelistApps)
        
        // Second instance should NOT re-migrate (flag is set)
        let secondStore = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        XCTAssertTrue(secondStore.proUserWhitelistApps.isEmpty)
    }
    
    func testMigrationWithEmptyLegacyData() {
        // Set up empty legacy data
        let emptyData = try! JSONEncoder().encode([UserWhitelistApp]())
        testDefaults.set(emptyData, forKey: SettingsStore.Key.userWhitelistAppsLegacy)
        
        // Migration should handle gracefully
        let migratingStore = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        XCTAssertTrue(migratingStore.proUserWhitelistApps.isEmpty)
    }
    
    func testMigrationWithNoLegacyData() {
        // No legacy data set
        let migratingStore = SettingsStore(defaults: testDefaults, skipMigration: false)
        
        XCTAssertTrue(migratingStore.proUserWhitelistApps.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    func testUserWhitelistAppEquality() {
        let app1 = UserWhitelistApp(bundleID: "com.test", displayName: "Test", appPath: "/path")
        let app2 = UserWhitelistApp(bundleID: "com.test", displayName: "Test", appPath: "/path")
        
        XCTAssertEqual(app1, app2)
    }
    
    func testUserWhitelistAppInequalityByBundleID() {
        let app1 = UserWhitelistApp(bundleID: "com.test1", displayName: "Test", appPath: "/path")
        let app2 = UserWhitelistApp(bundleID: "com.test2", displayName: "Test", appPath: "/path")
        
        XCTAssertNotEqual(app1, app2)
    }
    
    func testLargeNumberOfApps() {
        // Add 100 apps
        for i in 0..<100 {
            let app = makeTestApp(bundleID: "com.test.app\(i)", name: "App \(i)")
            sut.addProUserWhitelistApp(app)
        }
        
        XCTAssertEqual(sut.proUserWhitelistApps.count, 100)
        
        // Verify persistence
        let newStore = SettingsStore(defaults: testDefaults, skipMigration: true)
        XCTAssertEqual(newStore.proUserWhitelistApps.count, 100)
    }
}
