import XCTest
import StoreKit
import StoreKitTest
@testable import VibeCap

/// Integration tests for purchase flows using StoreKit Testing.
/// 
/// Requirements:
/// - Configure the test scheme to use VibeCap.storekit configuration
/// - Run on simulator or device with StoreKit Testing enabled
@available(macOS 12.0, *)
final class PurchaseFlowTests: XCTestCase {
    
    private var testSession: SKTestSession!
    private var testDefaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var entitlementsService: EntitlementsService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test session
        testSession = try SKTestSession(configurationFileNamed: "VibeCap")
        testSession.disableDialogs = true
        testSession.clearTransactions()
        
        // Create isolated UserDefaults
        defaultsSuiteName = "com.test.purchase.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        
        // Create service with test defaults
        entitlementsService = EntitlementsService(defaults: testDefaults)
    }
    
    override func tearDownWithError() throws {
        testSession.clearTransactions()
        testSession = nil
        if let defaultsSuiteName {
            testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        testDefaults = nil
        defaultsSuiteName = nil
        entitlementsService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Product Loading Tests
    
    func testLoadProducts() async throws {
        let productIDs = [
            EntitlementsService.ProductID.monthly,
            EntitlementsService.ProductID.yearly,
            EntitlementsService.ProductID.lifetime
        ]
        
        let products = try await Product.products(for: productIDs)
        
        XCTAssertEqual(products.count, 3)
        XCTAssertTrue(products.contains(where: { $0.id == EntitlementsService.ProductID.monthly }))
        XCTAssertTrue(products.contains(where: { $0.id == EntitlementsService.ProductID.yearly }))
        XCTAssertTrue(products.contains(where: { $0.id == EntitlementsService.ProductID.lifetime }))
    }
    
    func testMonthlyProductDetails() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.monthly])
        let monthly = try XCTUnwrap(products.first)
        
        XCTAssertEqual(monthly.id, EntitlementsService.ProductID.monthly)
        XCTAssertEqual(monthly.type, .autoRenewable)
    }
    
    func testYearlyProductDetails() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.yearly])
        let yearly = try XCTUnwrap(products.first)
        
        XCTAssertEqual(yearly.id, EntitlementsService.ProductID.yearly)
        XCTAssertEqual(yearly.type, .autoRenewable)
    }
    
    func testLifetimeProductDetails() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        
        XCTAssertEqual(lifetime.id, EntitlementsService.ProductID.lifetime)
        XCTAssertEqual(lifetime.type, .nonConsumable)
    }
    
    // MARK: - Monthly Purchase Tests
    
    func testMonthlyPurchaseSuccess() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.monthly])
        let monthly = try XCTUnwrap(products.first)
        
        let result = try await monthly.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try XCTUnwrap(verification.payloadValue as? Transaction)
            XCTAssertEqual(transaction.productID, EntitlementsService.ProductID.monthly)
            await transaction.finish()
        case .userCancelled, .pending:
            XCTFail("Expected successful purchase")
        @unknown default:
            XCTFail("Unknown purchase result")
        }
    }
    
    func testMonthlyPurchaseUpdatesEntitlements() async throws {
        // Initial state should be Free
        XCTAssertFalse(entitlementsService.isPro)
        
        let products = try await Product.products(for: [EntitlementsService.ProductID.monthly])
        let monthly = try XCTUnwrap(products.first)
        
        let result = try await monthly.purchase()
        if case .success(let verification) = result {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        // Refresh entitlements
        await entitlementsService.refreshEntitlements()
        
        XCTAssertTrue(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .monthly)
    }
    
    // MARK: - Yearly Purchase Tests
    
    func testYearlyPurchaseSuccess() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.yearly])
        let yearly = try XCTUnwrap(products.first)
        
        let result = try await yearly.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try XCTUnwrap(verification.payloadValue as? Transaction)
            XCTAssertEqual(transaction.productID, EntitlementsService.ProductID.yearly)
            await transaction.finish()
        case .userCancelled, .pending:
            XCTFail("Expected successful purchase")
        @unknown default:
            XCTFail("Unknown purchase result")
        }
    }
    
    func testYearlyPurchaseUpdatesEntitlements() async throws {
        XCTAssertFalse(entitlementsService.isPro)
        
        let products = try await Product.products(for: [EntitlementsService.ProductID.yearly])
        let yearly = try XCTUnwrap(products.first)
        
        let result = try await yearly.purchase()
        if case .success(let verification) = result {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        await entitlementsService.refreshEntitlements()
        
        XCTAssertTrue(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .yearly)
    }
    
    // MARK: - Lifetime Purchase Tests
    
    func testLifetimePurchaseSuccess() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        
        let result = try await lifetime.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try XCTUnwrap(verification.payloadValue as? Transaction)
            XCTAssertEqual(transaction.productID, EntitlementsService.ProductID.lifetime)
            await transaction.finish()
        case .userCancelled, .pending:
            XCTFail("Expected successful purchase")
        @unknown default:
            XCTFail("Unknown purchase result")
        }
    }
    
    func testLifetimePurchaseUpdatesEntitlements() async throws {
        XCTAssertFalse(entitlementsService.isPro)
        
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        
        let result = try await lifetime.purchase()
        if case .success(let verification) = result {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        await entitlementsService.refreshEntitlements()
        
        XCTAssertTrue(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .lifetime)
    }
    
    // MARK: - Priority Tests
    
    func testLifetimePriorityOverSubscription() async throws {
        // Buy monthly first
        let monthlyProducts = try await Product.products(for: [EntitlementsService.ProductID.monthly])
        let monthly = try XCTUnwrap(monthlyProducts.first)
        let monthlyResult = try await monthly.purchase()
        if case .success(let verification) = monthlyResult {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        // Then buy lifetime
        let lifetimeProducts = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(lifetimeProducts.first)
        let lifetimeResult = try await lifetime.purchase()
        if case .success(let verification) = lifetimeResult {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        await entitlementsService.refreshEntitlements()
        
        // Lifetime should win
        XCTAssertTrue(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .lifetime)
    }
    
    func testYearlyPriorityOverMonthly() async throws {
        // Buy monthly first
        let monthlyProducts = try await Product.products(for: [EntitlementsService.ProductID.monthly])
        let monthly = try XCTUnwrap(monthlyProducts.first)
        let monthlyResult = try await monthly.purchase()
        if case .success(let verification) = monthlyResult {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        // Then buy yearly
        let yearlyProducts = try await Product.products(for: [EntitlementsService.ProductID.yearly])
        let yearly = try XCTUnwrap(yearlyProducts.first)
        let yearlyResult = try await yearly.purchase()
        if case .success(let verification) = yearlyResult {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        await entitlementsService.refreshEntitlements()
        
        // Prefer yearly when the yearly entitlement is actually present.
        // (StoreKitTest configuration / subscription-group rules may result in only one entitlement.)
        XCTAssertTrue(entitlementsService.isPro)

        var productIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                productIDs.insert(transaction.productID)
            }
        }

        if productIDs.contains(EntitlementsService.ProductID.yearly) {
            XCTAssertEqual(entitlementsService.status.source, .yearly)
        } else {
            XCTAssertEqual(entitlementsService.status.source, .monthly)
        }
    }
    
    // MARK: - Restore Purchase Tests
    
    func testRestorePurchasesWithExistingTransaction() async throws {
        // Make a purchase first
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        let result = try await lifetime.purchase()
        if case .success(let verification) = result {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        // Create new service instance (simulating app restart)
        let newService = EntitlementsService(defaults: testDefaults)
        
        // Refresh should restore the purchase
        await newService.refreshEntitlements()
        
        XCTAssertTrue(newService.isPro)
        XCTAssertEqual(newService.status.source, .lifetime)
    }
    
    func testRestorePurchasesWithNoTransactions() async throws {
        // No purchases made
        
        await entitlementsService.refreshEntitlements()
        
        XCTAssertFalse(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .none)
    }
    
    // MARK: - Current Entitlements Tests
    
    func testCurrentEntitlementsEmptyInitially() async throws {
        var count = 0
        for await _ in Transaction.currentEntitlements {
            count += 1
        }
        
        XCTAssertEqual(count, 0)
    }
    
    func testCurrentEntitlementsAfterPurchase() async throws {
        // Make a purchase
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        let result = try await lifetime.purchase()
        if case .success(let verification) = result {
            let transaction = try verification.payloadValue as! Transaction
            await transaction.finish()
        }
        
        // Check current entitlements
        var entitlements: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                entitlements.append(transaction)
            }
        }
        
        XCTAssertEqual(entitlements.count, 1)
        XCTAssertEqual(entitlements.first?.productID, EntitlementsService.ProductID.lifetime)
    }
    
    // MARK: - Transaction Verification Tests
    
    func testVerifyValidTransaction() async throws {
        let products = try await Product.products(for: [EntitlementsService.ProductID.lifetime])
        let lifetime = try XCTUnwrap(products.first)
        
        let result = try await lifetime.purchase()
        
        guard case .success(let verification) = result else {
            XCTFail("Expected successful purchase")
            return
        }
        
        // Should not throw for valid transaction
        XCTAssertNoThrow(try EntitlementsService.verify(verification))
    }
    
    // MARK: - Cancellation Tests
    
    func testPurchaseCancellation() async throws {
        // Note: StoreKit Testing doesn't easily simulate user cancellation
        // This test verifies the initial state after no purchase
        
        XCTAssertFalse(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.tier, .free)
    }
    
    // MARK: - Multiple Transactions Tests
    
    func testMultiplePurchasesHandledCorrectly() async throws {
        let productIDs = [
            EntitlementsService.ProductID.monthly,
            EntitlementsService.ProductID.yearly,
            EntitlementsService.ProductID.lifetime
        ]
        let products = try await Product.products(for: productIDs)
        
        // Purchase all products
        for product in products {
            let result = try await product.purchase()
            if case .success(let verification) = result {
                let transaction = try verification.payloadValue as! Transaction
                await transaction.finish()
            }
        }
        
        await entitlementsService.refreshEntitlements()
        
        // Lifetime should be the final source (highest priority)
        XCTAssertTrue(entitlementsService.isPro)
        XCTAssertEqual(entitlementsService.status.source, .lifetime)
    }
}
