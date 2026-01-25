import AppKit
import StoreKit

/// Broadcast when Pro status changes.
extension Notification.Name {
    static let proStatusDidChange = Notification.Name("ProStatusDidChange")
}

/// Protocol for EntitlementsService (enables testing/DI).
protocol EntitlementsServiceProtocol {
    var isPro: Bool { get }
    var status: ProStatus { get }
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
    var expirationDate: Date?  // nil for lifetime or free
    var lastRefreshedAt: Date?

    static let `default` = ProStatus(tier: .free, source: .none, expirationDate: nil, lastRefreshedAt: nil)

    /// Convenience initializer to keep call sites/tests stable as the model evolves.
    init(tier: Tier, source: Source, expirationDate: Date? = nil, lastRefreshedAt: Date?) {
        self.tier = tier
        self.source = source
        self.expirationDate = expirationDate
        self.lastRefreshedAt = lastRefreshedAt
    }

    /// Localized description of the subscription source
    var sourceDisplayName: String {
        switch source {
        case .monthly: return L("settings.proStatus.source.monthly")
        case .yearly: return L("settings.proStatus.source.yearly")
        case .lifetime: return L("settings.proStatus.source.lifetime")
        case .none: return L("settings.proStatus.source.none")
        case .unknown: return L("settings.proStatus.source.unknown")
        }
    }
}

/// StoreKit 2 entitlements manager (SSOT for Free/Pro).
///
/// Design goals:
/// - One place to decide Pro status (incl. "lifetime wins").
/// - Refresh on launch, foreground, and Transaction.updates.
/// - Optimistic offline: refresh failures keep last known status.
final class EntitlementsService: EntitlementsServiceProtocol {
    static let shared = EntitlementsService()

    // MARK: - Constants

    enum ProductID {
        static let monthly = "com.luke.vibecapture.pro.monthly"
        static let yearly = "com.luke.vibecapture.pro.yearly"
        static let lifetime = "com.luke.vibecapture.pro.lifetime"
    }

    enum DefaultsKey {
        static let cachedProStatus = "IAPCachedProStatus"
    }

    // MARK: - State

    private let defaults: UserDefaults

    private(set) var status: ProStatus {
        didSet {
            NotificationCenter.default.post(name: .proStatusDidChange, object: self)
        }
    }

    var isPro: Bool { status.tier == .pro }

    private var transactionUpdatesTask: Task<Void, Never>?

    /// Designated initializer with dependency injection support.
    /// - Parameter defaults: UserDefaults instance for caching (defaults to .standard)
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.status = Self.loadCachedStatus(from: defaults)
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
            self.status = ProStatus(
                tier: computed.tier,
                source: computed.source,
                expirationDate: computed.expirationDate,
                lastRefreshedAt: now
            )
            Self.saveCachedStatus(self.status, to: defaults)
        } catch {
            // Optimistic offline: keep last known status, but still stamp refresh time.
            self.status.lastRefreshedAt = now
            Self.saveCachedStatus(self.status, to: defaults)
        }
    }

    private static func computeProStatus(now: Date) async throws -> (tier: ProStatus.Tier, source: ProStatus.Source, expirationDate: Date?) {
        var hasLifetime = false
        var monthlyExpiration: Date?
        var yearlyExpiration: Date?

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
                    monthlyExpiration = transaction.expirationDate
                }

            case ProductID.yearly:
                if Self.isSubscriptionActive(transaction, now: now) {
                    yearlyExpiration = transaction.expirationDate
                }

            default:
                break
            }
        }

        // Lifetime wins (no expiration).
        if hasLifetime { return (.pro, .lifetime, nil) }
        if let exp = yearlyExpiration { return (.pro, .yearly, exp) }
        if let exp = monthlyExpiration { return (.pro, .monthly, exp) }

        return (.free, .none, nil)
    }

    private static func isSubscriptionActive(_ transaction: Transaction, now: Date) -> Bool {
        // Subscriptions should have expirationDate; be defensive.
        if let expiration = transaction.expirationDate {
            return expiration > now
        }
        // Safer default: if StoreKit doesn't provide an expiration date for a subscription,
        // we should not grant Pro.
        NSLog("VibeCap IAP: subscription missing expirationDate; denying. productID=%{public}@", transaction.productID)
        return false
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

    static func loadCachedStatus(from defaults: UserDefaults = .standard) -> ProStatus {
        guard
            let data = defaults.data(forKey: DefaultsKey.cachedProStatus),
            let value = try? JSONDecoder().decode(ProStatus.self, from: data)
        else {
            return .default
        }
        return value
    }

    static func saveCachedStatus(_ status: ProStatus, to defaults: UserDefaults = .standard) {
        let data = try? JSONEncoder().encode(status)
        defaults.set(data, forKey: DefaultsKey.cachedProStatus)
    }

    /// For testing: directly set status without StoreKit.
    func setStatus(_ newStatus: ProStatus) {
        self.status = newStatus
        Self.saveCachedStatus(newStatus, to: defaults)
    }
}

