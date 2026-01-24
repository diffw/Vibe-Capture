import AppKit
import StoreKit

/// Purchase + restore helpers for StoreKit 2.
final class PurchaseService {
    static let shared = PurchaseService()

    private init() {}

    private var productsByID: [String: Product] = [:]

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
    }

    func product(id: String) -> Product? {
        productsByID[id]
    }

    /// Minimal purchase picker used by Settings until Paywall UI lands.
    @MainActor
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

    @MainActor
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

    @MainActor
    func openManageSubscriptions(from window: NSWindow?) {
        // macOS: open Apple-managed subscriptions page.
        // (StoreKit does not currently provide a native "Manage Subscriptions" sheet API on macOS in our toolchain.)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    @MainActor
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
        await purchase(product: product, from: window)
    }

    @MainActor
    private func purchase(product: Product, from window: NSWindow?) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try EntitlementsService.verify(verification)
                await transaction.finish()
                await EntitlementsService.shared.refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            showErrorAlert(from: window, message: L("paywall.error.generic"))
        }
    }

    @MainActor
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

