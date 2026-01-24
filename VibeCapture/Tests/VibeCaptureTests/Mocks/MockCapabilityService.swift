import Foundation
@testable import VibeCapture

/// Mock implementation of CapabilityServiceProtocol for unit testing.
final class MockCapabilityService: CapabilityServiceProtocol {
    
    // MARK: - Configuration
    
    /// Override table for testing specific capabilities.
    /// If a key is in this dictionary, its value is returned directly.
    /// Otherwise, falls back to the standard logic.
    var overrides: [CapabilityKey: Bool] = [:]
    
    /// Underlying entitlements service (can be mocked).
    var entitlements: EntitlementsServiceProtocol
    
    // MARK: - Test Helpers
    
    /// Track which capabilities were checked.
    private(set) var checkedCapabilities: [CapabilityKey] = []
    
    // MARK: - Initialization
    
    init(entitlements: EntitlementsServiceProtocol = MockEntitlementsService()) {
        self.entitlements = entitlements
    }
    
    // MARK: - Protocol Methods
    
    func canUse(_ key: CapabilityKey) -> Bool {
        checkedCapabilities.append(key)
        
        // Check overrides first
        if let override = overrides[key] {
            return override
        }
        
        // Fall back to standard capability table logic
        guard let access = CapabilityService.table[key] else {
            return false
        }
        
        switch access {
        case .free:
            return true
        case .pro:
            return entitlements.isPro
        }
    }
    
    // MARK: - Convenience Methods for Testing
    
    /// Allow a specific capability regardless of Pro status.
    func allow(_ key: CapabilityKey) {
        overrides[key] = true
    }
    
    /// Deny a specific capability regardless of Pro status.
    func deny(_ key: CapabilityKey) {
        overrides[key] = false
    }
    
    /// Reset all test state.
    func reset() {
        overrides.removeAll()
        checkedCapabilities.removeAll()
    }
}
