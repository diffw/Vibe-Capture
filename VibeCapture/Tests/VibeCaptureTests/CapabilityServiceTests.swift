import XCTest
@testable import VibeCap

/// Unit tests for CapabilityService.
final class CapabilityServiceTests: XCTestCase {
    
    private var mockEntitlements: MockEntitlementsService!
    private var sut: CapabilityService!
    
    override func setUp() {
        super.setUp()
        mockEntitlements = MockEntitlementsService()
        sut = CapabilityService(entitlements: mockEntitlements)
    }
    
    override func tearDown() {
        mockEntitlements = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Free Capabilities Tests
    
    func testCaptureAreaIsAlwaysAvailable() {
        mockEntitlements.setFree()
        XCTAssertTrue(sut.canUse(.captureArea))
        
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.captureArea))
    }
    
    func testCaptureSaveIsAlwaysAvailable() {
        mockEntitlements.setFree()
        XCTAssertTrue(sut.canUse(.captureSave))
        
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.captureSave))
    }
    
    func testCaptureAutosaveIsAlwaysAvailable() {
        mockEntitlements.setFree()
        XCTAssertTrue(sut.canUse(.captureAutosave))
        
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.captureAutosave))
    }
    
    func testAnnotationsArrowIsAlwaysAvailable() {
        mockEntitlements.setFree()
        XCTAssertTrue(sut.canUse(.annotationsArrow))
        
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsArrow))
    }
    
    // MARK: - Pro Capabilities Tests (Free User)
    
    func testAnnotationsShapesRequiresPro_FreeUser() {
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(.annotationsShapes))
    }
    
    func testAnnotationsNumberingRequiresPro_FreeUser() {
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(.annotationsNumbering))
    }
    
    func testAnnotationsColorsRequiresPro_FreeUser() {
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(.annotationsColors))
    }
    
    // MARK: - Pro Capabilities Tests (Pro User)
    
    func testAnnotationsShapesAvailableForPro() {
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsShapes))
    }
    
    func testAnnotationsNumberingAvailableForPro() {
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsNumbering))
    }
    
    func testAnnotationsColorsAvailableForPro() {
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsColors))
    }
    
    // MARK: - Pro Source Variations
    
    func testProCapabilitiesWithMonthlySubscription() {
        mockEntitlements.setPro(source: .monthly)
        
        XCTAssertTrue(sut.canUse(.annotationsShapes))
        XCTAssertTrue(sut.canUse(.annotationsNumbering))
        XCTAssertTrue(sut.canUse(.annotationsColors))
    }
    
    func testProCapabilitiesWithYearlySubscription() {
        mockEntitlements.setPro(source: .yearly)
        
        XCTAssertTrue(sut.canUse(.annotationsShapes))
        XCTAssertTrue(sut.canUse(.annotationsNumbering))
        XCTAssertTrue(sut.canUse(.annotationsColors))
    }
    
    func testProCapabilitiesWithLifetime() {
        mockEntitlements.setPro(source: .lifetime)
        
        XCTAssertTrue(sut.canUse(.annotationsShapes))
        XCTAssertTrue(sut.canUse(.annotationsNumbering))
        XCTAssertTrue(sut.canUse(.annotationsColors))
    }
    
    // MARK: - Unknown Capability Tests
    
    func testUnknownCapabilityReturnsFalse() {
        let unknownKey = CapabilityKey(rawValue: "cap.unknown.feature")
        
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(unknownKey))
        
        mockEntitlements.setPro()
        XCTAssertFalse(sut.canUse(unknownKey))
    }
    
    // MARK: - Capability Table Tests
    
    func testCapabilityTableContainsAllExpectedKeys() {
        let expectedFreeKeys: [CapabilityKey] = [
            .captureArea,
            .captureSave,
            .captureAutosave,
            .annotationsArrow
        ]
        
        let expectedProKeys: [CapabilityKey] = [
            .annotationsShapes,
            .annotationsNumbering,
            .annotationsColors
        ]
        
        for key in expectedFreeKeys {
            XCTAssertNotNil(CapabilityService.table[key], "Missing capability: \(key.rawValue)")
            XCTAssertEqual(CapabilityService.table[key], .free, "Expected \(key.rawValue) to be .free")
        }
        
        for key in expectedProKeys {
            XCTAssertNotNil(CapabilityService.table[key], "Missing capability: \(key.rawValue)")
            XCTAssertEqual(CapabilityService.table[key], .pro, "Expected \(key.rawValue) to be .pro")
        }
    }
    
    // MARK: - Transition Tests
    
    func testCapabilitiesUpdateWhenProStatusChanges() {
        // Start as Free
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(.annotationsShapes))
        
        // Upgrade to Pro
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsShapes))
        
        // Downgrade to Free
        mockEntitlements.setFree()
        XCTAssertFalse(sut.canUse(.annotationsShapes))
    }
    
    func testAllFreeCapabilitiesRemainAvailableAfterDowngrade() {
        // Start as Pro
        mockEntitlements.setPro()
        
        // Downgrade to Free
        mockEntitlements.setFree()
        
        // All Free capabilities should still work
        XCTAssertTrue(sut.canUse(.captureArea))
        XCTAssertTrue(sut.canUse(.captureSave))
        XCTAssertTrue(sut.canUse(.captureAutosave))
        XCTAssertTrue(sut.canUse(.annotationsArrow))
    }
    
    func testAllProCapabilitiesUnavailableAfterDowngrade() {
        // Start as Pro
        mockEntitlements.setPro()
        XCTAssertTrue(sut.canUse(.annotationsShapes))
        
        // Downgrade to Free
        mockEntitlements.setFree()
        
        // All Pro capabilities should be unavailable
        XCTAssertFalse(sut.canUse(.annotationsShapes))
        XCTAssertFalse(sut.canUse(.annotationsNumbering))
        XCTAssertFalse(sut.canUse(.annotationsColors))
    }
}
