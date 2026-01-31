import Foundation
@testable import VibeCap

/// Mock implementation of EntitlementsServiceProtocol for unit testing.
final class MockEntitlementsService: EntitlementsServiceProtocol {
    
    // MARK: - Protocol Properties
    
    var status: ProStatus = .default
    
    var isPro: Bool { status.tier == .pro }
    
    // MARK: - Test Helpers
    
    /// Track how many times refreshEntitlements was called.
    private(set) var refreshCallCount = 0
    
    /// Error to throw on next refresh (if set).
    var refreshError: Error?
    
    /// Simulated delay for refresh (in seconds).
    var refreshDelay: TimeInterval = 0
    
    // MARK: - Protocol Methods
    
    @MainActor
    func refreshEntitlements() async {
        refreshCallCount += 1
        
        if refreshDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
        }
        
        if let error = refreshError {
            // Simulate optimistic offline: don't change status on error
            status.lastRefreshedAt = Date()
            return
        }
        
        status.lastRefreshedAt = Date()
    }
    
    // MARK: - Convenience Methods for Testing
    
    /// Set status to Free tier.
    func setFree() {
        status = ProStatus(tier: .free, source: .none, lastRefreshedAt: Date())
    }
    
    /// Set status to Pro tier with specified source.
    func setPro(source: ProStatus.Source = .lifetime) {
        status = ProStatus(tier: .pro, source: source, lastRefreshedAt: Date())
    }
    
    /// Reset all test state.
    func reset() {
        status = .default
        refreshCallCount = 0
        refreshError = nil
        refreshDelay = 0
    }
}
