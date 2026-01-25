import XCTest
@testable import VibeCap

/// Unit tests for EntitlementsService.
final class EntitlementsServiceTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var sut: EntitlementsService!
    
    override func setUp() {
        super.setUp()
        // Create a unique UserDefaults suite for each test
        defaultsSuiteName = "com.test.entitlements.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
    }
    
    override func tearDown() {
        if let defaultsSuiteName {
            testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        testDefaults = nil
        defaultsSuiteName = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialStatusIsFreeWhenNoCache() {
        sut = EntitlementsService(defaults: testDefaults)
        
        XCTAssertEqual(sut.status.tier, .free)
        XCTAssertEqual(sut.status.source, .none)
        XCTAssertFalse(sut.isPro)
    }
    
    func testStatusFromCache() {
        // Pre-populate cache
        let cachedStatus = ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date())
        EntitlementsService.saveCachedStatus(cachedStatus, to: testDefaults)
        
        sut = EntitlementsService(defaults: testDefaults)
        
        XCTAssertEqual(sut.status.tier, .pro)
        XCTAssertEqual(sut.status.source, .lifetime)
        XCTAssertTrue(sut.isPro)
    }
    
    func testStatusFromCacheWithMonthly() {
        let cachedStatus = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: Date())
        EntitlementsService.saveCachedStatus(cachedStatus, to: testDefaults)
        
        sut = EntitlementsService(defaults: testDefaults)
        
        XCTAssertEqual(sut.status.tier, .pro)
        XCTAssertEqual(sut.status.source, .monthly)
    }
    
    func testStatusFromCacheWithYearly() {
        let cachedStatus = ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: Date())
        EntitlementsService.saveCachedStatus(cachedStatus, to: testDefaults)
        
        sut = EntitlementsService(defaults: testDefaults)
        
        XCTAssertEqual(sut.status.tier, .pro)
        XCTAssertEqual(sut.status.source, .yearly)
    }
    
    func testInvalidCacheDataReturnsDefault() {
        // Write invalid data to cache
        testDefaults.set("invalid data".data(using: .utf8), forKey: EntitlementsService.DefaultsKey.cachedProStatus)
        
        sut = EntitlementsService(defaults: testDefaults)
        
        XCTAssertEqual(sut.status.tier, .free)
        XCTAssertEqual(sut.status.source, .none)
    }
    
    // MARK: - isPro Computed Property Tests
    
    func testIsProReturnsFalseForFreeTier() {
        sut = EntitlementsService(defaults: testDefaults)
        sut.setStatus(ProStatus(tier: .free, source: .none, lastRefreshedAt: Date()))
        
        XCTAssertFalse(sut.isPro)
    }
    
    func testIsProReturnsTrueForProTier() {
        sut = EntitlementsService(defaults: testDefaults)
        sut.setStatus(ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: Date()))
        
        XCTAssertTrue(sut.isPro)
    }
    
    // MARK: - setStatus Tests
    
    func testSetStatusUpdatesCacheCorrectly() {
        sut = EntitlementsService(defaults: testDefaults)
        let newStatus = ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date())
        
        sut.setStatus(newStatus)
        
        // Verify the cache was updated
        let cachedStatus = EntitlementsService.loadCachedStatus(from: testDefaults)
        XCTAssertEqual(cachedStatus.tier, .pro)
        XCTAssertEqual(cachedStatus.source, .lifetime)
    }
    
    func testSetStatusTriggersNotification() {
        sut = EntitlementsService(defaults: testDefaults)
        let expectation = XCTNSNotificationExpectation(
            name: .proStatusDidChange,
            object: sut
        )
        
        sut.setStatus(ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: Date()))
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Cache Helper Tests
    
    func testSaveCachedStatusWritesToDefaults() {
        let status = ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: Date())
        
        EntitlementsService.saveCachedStatus(status, to: testDefaults)
        
        let data = testDefaults.data(forKey: EntitlementsService.DefaultsKey.cachedProStatus)
        XCTAssertNotNil(data)
    }
    
    func testLoadCachedStatusReturnsDefaultWhenEmpty() {
        let status = EntitlementsService.loadCachedStatus(from: testDefaults)
        
        XCTAssertEqual(status, ProStatus.default)
    }
    
    func testSaveAndLoadRoundTrip() {
        let original = ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date())
        
        EntitlementsService.saveCachedStatus(original, to: testDefaults)
        let loaded = EntitlementsService.loadCachedStatus(from: testDefaults)
        
        XCTAssertEqual(loaded.tier, original.tier)
        XCTAssertEqual(loaded.source, original.source)
    }
    
    // MARK: - Product ID Tests
    
    func testProductIDsAreCorrect() {
        XCTAssertEqual(EntitlementsService.ProductID.monthly, "com.luke.vibecapture.pro.monthly")
        XCTAssertEqual(EntitlementsService.ProductID.yearly, "com.luke.vibecapture.pro.yearly")
        XCTAssertEqual(EntitlementsService.ProductID.lifetime, "com.luke.vibecapture.pro.lifetime")
    }
    
    // MARK: - Notification Tests
    
    func testNotificationPostedOnStatusChange() {
        sut = EntitlementsService(defaults: testDefaults)
        var notificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: sut,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        
        sut.setStatus(ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date()))
        
        // Give notification time to be delivered
        let expectation = XCTestExpectation(description: "Notification delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(notificationReceived)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testMultipleNotificationsForMultipleChanges() {
        sut = EntitlementsService(defaults: testDefaults)
        var notificationCount = 0
        
        let observer = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: sut,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        
        sut.setStatus(ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: Date()))
        sut.setStatus(ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: Date()))
        sut.setStatus(ProStatus(tier: .free, source: .none, lastRefreshedAt: Date()))
        
        let expectation = XCTestExpectation(description: "Notifications delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(notificationCount, 3)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Priority Tests (Verified via setStatus)
    
    func testLifetimeSourceIsRecognized() {
        sut = EntitlementsService(defaults: testDefaults)
        sut.setStatus(ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: Date()))
        
        XCTAssertTrue(sut.isPro)
        XCTAssertEqual(sut.status.source, .lifetime)
    }
    
    func testYearlySourceIsRecognized() {
        sut = EntitlementsService(defaults: testDefaults)
        sut.setStatus(ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: Date()))
        
        XCTAssertTrue(sut.isPro)
        XCTAssertEqual(sut.status.source, .yearly)
    }
    
    func testMonthlySourceIsRecognized() {
        sut = EntitlementsService(defaults: testDefaults)
        sut.setStatus(ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: Date()))
        
        XCTAssertTrue(sut.isPro)
        XCTAssertEqual(sut.status.source, .monthly)
    }
}
