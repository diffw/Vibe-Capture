import AppKit
import StoreKit

/// Broadcast when Pro status changes.
extension Notification.Name {
    static let proStatusDidChange = Notification.Name("ProStatusDidChange")
}

/// Free/Pro state derived from StoreKit 2 entitlements.
struct ProStatus: Codable, Equatable {
    enum Tier: String, Codable {
        case free
        case pro
    }

    enum Source: String, Codable {
        case none
        case monthly
        case yearly
        case lifetime
        case unknown
    }

    var tier: Tier
    var source: Source
    var lastRefreshedAt: Date?

    static let `default` = ProStatus(tier: .free, source: .none, lastRefreshedAt: nil)
}

/// StoreKit 2 entitlements manager (SSOT for Free/Pro).
///
/// Design goals:
/// - One place to decide Pro status (incl. "lifetime wins").
/// - Refresh on launch, foreground, and Transaction.updates.
/// - Optimistic offline: refresh failures keep last known status.
final class EntitlementsService {
    static let shared = EntitlementsService()

    // MARK: - Constants

    enum ProductID {
        static let monthly = "com.luke.vibecapture.pro.monthly"
        static let yearly = "com.luke.vibecapture.pro.yearly"
        static let lifetime = "com.luke.vibecapture.pro.lifetime"
    }

    private enum DefaultsKey {
        static let cachedProStatus = "IAPCachedProStatus"
    }

    // MARK: - State

    private(set) var status: ProStatus {
        didSet {
            NotificationCenter.default.post(name: .proStatusDidChange, object: self)
        }
    }

    var isPro: Bool { status.tier == .pro }

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        self.status = Self.loadCachedStatus()
    }

    // MARK: - Lifecycle

    /// Call once at app launch.
    func start() {
        // Start listening to transaction updates.
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                for await _ in Transaction.updates {
                    await self.refreshEntitlements()
                }
            }
        }

        Task { [weak self] in
            await self?.refreshEntitlements()
        }
    }

    func stop() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = nil
    }

    // MARK: - Refresh

    /// Refresh current entitlements and update `status`.
    /// Safe to call frequently; errors do not downgrade (optimistic offline).
    @MainActor
    func refreshEntitlements() async {
        let now = Date()
        do {
            let computed = try await Self.computeProStatus(now: now)
            self.status = ProStatus(tier: computed.tier, source: computed.source, lastRefreshedAt: now)
            Self.saveCachedStatus(self.status)
        } catch {
            // Optimistic offline: keep last known status, but still stamp refresh time.
            self.status.lastRefreshedAt = now
            Self.saveCachedStatus(self.status)
        }
    }

    private static func computeProStatus(now: Date) async throws -> (tier: ProStatus.Tier, source: ProStatus.Source) {
        var hasLifetime = false
        var hasMonthly = false
        var hasYearly = false

        for await result in Transaction.currentEntitlements {
            let transaction = try Self.verify(result)

            // Ignore revoked.
            if transaction.revocationDate != nil {
                continue
            }

            switch transaction.productID {
            case ProductID.lifetime:
                hasLifetime = true

            case ProductID.monthly:
                if Self.isSubscriptionActive(transaction, now: now) {
                    hasMonthly = true
                }

            case ProductID.yearly:
                if Self.isSubscriptionActive(transaction, now: now) {
                    hasYearly = true
                }

            default:
                break
            }
        }

        // Lifetime wins.
        if hasLifetime { return (.pro, .lifetime) }
        if hasYearly { return (.pro, .yearly) }
        if hasMonthly { return (.pro, .monthly) }

        return (.free, .none)
    }

    private static func isSubscriptionActive(_ transaction: Transaction, now: Date) -> Bool {
        // Subscriptions should have expirationDate; be defensive.
        if let expiration = transaction.expirationDate {
            return expiration > now
        }
        return true
    }

    /// Shared verification helper for StoreKit 2.
    static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Cache

    private static func loadCachedStatus() -> ProStatus {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKey.cachedProStatus),
            let value = try? JSONDecoder().decode(ProStatus.self, from: data)
        else {
            return .default
        }
        return value
    }

    private static func saveCachedStatus(_ status: ProStatus) {
        let data = try? JSONEncoder().encode(status)
        UserDefaults.standard.set(data, forKey: DefaultsKey.cachedProStatus)
    }
}

