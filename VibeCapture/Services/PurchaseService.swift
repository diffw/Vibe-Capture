import AppKit
import StoreKit

/// Purchase + restore helpers for StoreKit 2.
@MainActor
final class PurchaseService {
    static let shared = PurchaseService()

    private init() {}

    private var productsByID: [String: Product] = [:]

    /// Cached trial eligibility status (refreshed when products load)
    private(set) var isEligibleForTrial: Bool = false

    func loadProductsIfNeeded() async throws {
        if !productsByID.isEmpty { return }
        let ids = [
            EntitlementsService.ProductID.monthly,
            EntitlementsService.ProductID.yearly,
            EntitlementsService.ProductID.lifetime,
        ]
        let products = try await Product.products(for: ids)
        var map: [String: Product] = [:]
        for p in products {
            map[p.id] = p
        }
        productsByID = map

        // Check trial eligibility (based on yearly subscription)
        await refreshTrialEligibility()
    }

    /// Force refresh products and trial eligibility
    func refreshProducts() async throws {
        productsByID = [:]
        try await loadProductsIfNeeded()
    }

    /// Check if user is eligible for introductory offer (free trial)
    func refreshTrialEligibility() async {
        // Check eligibility for yearly subscription (primary trial product)
        if let yearly = productsByID[EntitlementsService.ProductID.yearly] {
            isEligibleForTrial = await yearly.subscription?.isEligibleForIntroOffer ?? false
        } else if let monthly = productsByID[EntitlementsService.ProductID.monthly] {
            isEligibleForTrial = await monthly.subscription?.isEligibleForIntroOffer ?? false
        } else {
            isEligibleForTrial = false
        }
    }

    /// Check trial eligibility for a specific product
    func isEligibleForTrial(productID: String) async -> Bool {
        guard let product = productsByID[productID],
              let subscription = product.subscription else {
            return false
        }
        return await subscription.isEligibleForIntroOffer
    }

    /// Get introductory offer info for a product (if eligible)
    func introductoryOffer(for productID: String) async -> Product.SubscriptionOffer? {
        guard let product = productsByID[productID],
              let subscription = product.subscription,
              await subscription.isEligibleForIntroOffer else {
            return nil
        }
        return subscription.introductoryOffer
    }

    /// Get trial duration in days for a product (if has free trial)
    func trialDays(for productID: String) async -> Int? {
        guard let offer = await introductoryOffer(for: productID),
              offer.paymentMode == .freeTrial else {
            return nil
        }
        // Convert period to days
        let period = offer.period
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    func product(id: String) -> Product? {
        productsByID[id]
    }

    func allProducts() -> [Product] {
        return [
            productsByID[EntitlementsService.ProductID.monthly],
            productsByID[EntitlementsService.ProductID.yearly],
            productsByID[EntitlementsService.ProductID.lifetime],
        ].compactMap { $0 }
    }

    /// Minimal purchase picker used by Settings until Paywall UI lands.
    func presentUpgradeOptions(from window: NSWindow?) {
        Task {
            do {
                try await loadProductsIfNeeded()
            } catch {
                showErrorAlert(from: window, message: L("paywall.error.generic"))
                return
            }

            let yearly = productsByID[EntitlementsService.ProductID.yearly]
            let monthly = productsByID[EntitlementsService.ProductID.monthly]
            let lifetime = productsByID[EntitlementsService.ProductID.lifetime]

            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = L("paywall.title")
            alert.informativeText = L("paywall.subtitle")

            if let yearly {
                alert.addButton(withTitle: "\(L("paywall.option.yearly")) · \(yearly.displayPrice)")
            }
            if let monthly {
                alert.addButton(withTitle: "\(L("paywall.option.monthly")) · \(monthly.displayPrice)")
            }
            if let lifetime {
                alert.addButton(withTitle: "\(L("paywall.option.lifetime")) · \(lifetime.displayPrice)")
            }
            alert.addButton(withTitle: L("button.cancel"))

            if let window {
                NSApp.activate(ignoringOtherApps: true)
                let resp = alert.runModal()
                await handlePurchaseSelection(response: resp, yearly: yearly, monthly: monthly, lifetime: lifetime, window: window)
            } else {
                let resp = alert.runModal()
                await handlePurchaseSelection(response: resp, yearly: yearly, monthly: monthly, lifetime: lifetime, window: nil)
            }
        }
    }

    func restorePurchases(from window: NSWindow?) {
        Task {
            do {
                try await AppStore.sync()
                await EntitlementsService.shared.refreshEntitlements()
            } catch {
                showErrorAlert(from: window, message: L("paywall.error.generic"))
            }
        }
    }

    func openManageSubscriptions(from window: NSWindow?) {
        // macOS: open Apple-managed subscriptions page.
        // (StoreKit does not currently provide a native "Manage Subscriptions" sheet API on macOS in our toolchain.)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Purchase

    enum PurchaseResult {
        case success
        case cancelled
        case pending
        case failed(String)
    }

    /// Public purchase method for PaywallWindowController
    func purchase(productID: String) async -> PurchaseResult {
        guard let product = productsByID[productID] else {
            return .failed(L("paywall.error.generic"))
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try EntitlementsService.verify(verification)
                await transaction.finish()
                await EntitlementsService.shared.refreshEntitlements()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(L("paywall.error.generic"))
            }
        } catch {
            return .failed(L("paywall.error.generic"))
        }
    }

    // MARK: - Private

    private func handlePurchaseSelection(
        response: NSApplication.ModalResponse,
        yearly: Product?,
        monthly: Product?,
        lifetime: Product?,
        window: NSWindow?
    ) async {
        // Buttons are added in order; Cancel is last.
        // If a product is missing, its button isn't added.
        // We re-map by checking titles in the same order we added.
        let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        var candidates: [Product] = []
        if let yearly { candidates.append(yearly) }
        if let monthly { candidates.append(monthly) }
        if let lifetime { candidates.append(lifetime) }

        if buttonIndex < 0 || buttonIndex >= candidates.count {
            return // Cancel or unexpected
        }
        let product = candidates[buttonIndex]
        _ = await purchase(productID: product.id)
    }

    private func purchase(product: Product, from window: NSWindow?) async {
        let result = await purchase(productID: product.id)
        if case .failed(let message) = result {
            showErrorAlert(from: window, message: message)
        }
    }

    private func showErrorAlert(from window: NSWindow?, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.addButton(withTitle: L("button.ok"))
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}

