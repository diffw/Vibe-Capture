import XCTest
@testable import VibeCapture

/// Unit tests for ProStatus data model.
final class ProStatusTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDefaultStatusIsFree() {
        let status = ProStatus.default
        
        XCTAssertEqual(status.tier, .free)
        XCTAssertEqual(status.source, .none)
        XCTAssertNil(status.lastRefreshedAt)
    }
    
    func testInitializationWithAllParameters() {
        let now = Date()
        let status = ProStatus(tier: .pro, source: .lifetime, lastRefreshedAt: now)
        
        XCTAssertEqual(status.tier, .pro)
        XCTAssertEqual(status.source, .lifetime)
        XCTAssertEqual(status.lastRefreshedAt, now)
    }
    
    // MARK: - Tier Tests
    
    func testTierFreeRawValue() {
        XCTAssertEqual(ProStatus.Tier.free.rawValue, "free")
    }
    
    func testTierProRawValue() {
        XCTAssertEqual(ProStatus.Tier.pro.rawValue, "pro")
    }
    
    // MARK: - Source Tests
    
    func testSourceNoneRawValue() {
        XCTAssertEqual(ProStatus.Source.none.rawValue, "none")
    }
    
    func testSourceMonthlyRawValue() {
        XCTAssertEqual(ProStatus.Source.monthly.rawValue, "monthly")
    }
    
    func testSourceYearlyRawValue() {
        XCTAssertEqual(ProStatus.Source.yearly.rawValue, "yearly")
    }
    
    func testSourceLifetimeRawValue() {
        XCTAssertEqual(ProStatus.Source.lifetime.rawValue, "lifetime")
    }
    
    func testSourceUnknownRawValue() {
        XCTAssertEqual(ProStatus.Source.unknown.rawValue, "unknown")
    }
    
    // MARK: - Codable Tests
    
    func testEncodingAndDecoding() throws {
        let now = Date()
        let original = ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: now)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProStatus.self, from: data)
        
        XCTAssertEqual(decoded.tier, original.tier)
        XCTAssertEqual(decoded.source, original.source)
        // Date comparison with some tolerance for encoding precision
        XCTAssertEqual(decoded.lastRefreshedAt?.timeIntervalSince1970 ?? 0,
                       original.lastRefreshedAt?.timeIntervalSince1970 ?? 0,
                       accuracy: 0.001)
    }
    
    func testDecodingDefaultStatus() throws {
        let json = """
        {
            "tier": "free",
            "source": "none"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(ProStatus.self, from: json)
        
        XCTAssertEqual(decoded.tier, .free)
        XCTAssertEqual(decoded.source, .none)
        XCTAssertNil(decoded.lastRefreshedAt)
    }
    
    func testDecodingProLifetimeStatus() throws {
        let json = """
        {
            "tier": "pro",
            "source": "lifetime",
            "lastRefreshedAt": 1706000000
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(ProStatus.self, from: json)
        
        XCTAssertEqual(decoded.tier, .pro)
        XCTAssertEqual(decoded.source, .lifetime)
        XCTAssertNotNil(decoded.lastRefreshedAt)
    }
    
    // MARK: - Equatable Tests
    
    func testEqualityForSameValues() {
        let now = Date()
        let status1 = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: now)
        let status2 = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: now)
        
        XCTAssertEqual(status1, status2)
    }
    
    func testInequalityForDifferentTier() {
        let status1 = ProStatus(tier: .free, source: .none, lastRefreshedAt: nil)
        let status2 = ProStatus(tier: .pro, source: .none, lastRefreshedAt: nil)
        
        XCTAssertNotEqual(status1, status2)
    }
    
    func testInequalityForDifferentSource() {
        let status1 = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: nil)
        let status2 = ProStatus(tier: .pro, source: .yearly, lastRefreshedAt: nil)
        
        XCTAssertNotEqual(status1, status2)
    }
    
    func testInequalityForDifferentRefreshTime() {
        let now = Date()
        let later = now.addingTimeInterval(60)
        let status1 = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: now)
        let status2 = ProStatus(tier: .pro, source: .monthly, lastRefreshedAt: later)
        
        XCTAssertNotEqual(status1, status2)
    }
    
    // MARK: - Mutation Tests
    
    func testMutatingTier() {
        var status = ProStatus.default
        status.tier = .pro
        
        XCTAssertEqual(status.tier, .pro)
        XCTAssertEqual(status.source, .none) // Source unchanged
    }
    
    func testMutatingSource() {
        var status = ProStatus.default
        status.source = .lifetime
        
        XCTAssertEqual(status.tier, .free) // Tier unchanged
        XCTAssertEqual(status.source, .lifetime)
    }
    
    func testMutatingLastRefreshedAt() {
        var status = ProStatus.default
        let now = Date()
        status.lastRefreshedAt = now
        
        XCTAssertEqual(status.lastRefreshedAt, now)
    }
}
