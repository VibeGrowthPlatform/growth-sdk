import Foundation
import StoreKit
import XCTest
@testable import VibeGrowthSDK

final class StoreKitPurchaseObserverTests: XCTestCase {

    private var observer: StoreKitPurchaseObserver!
    private var capturingTracker: CapturingRevenueTracker!

    override func setUp() {
        super.setUp()
        let config = VibeGrowthConfig(appId: "test", apiKey: "key", baseUrl: "http://localhost")
        let apiClient = ApiClient(config: config)
        let store = UserDefaultsStore()
        let identityManager = UserIdentityManager(store: store)
        capturingTracker = CapturingRevenueTracker(apiClient: apiClient, identityManager: identityManager)
        observer = StoreKitPurchaseObserver(revenueTracker: capturingTracker)
        observer.productPriceResolver = { productId in
            if productId == "gems_50" { return (price: 4.99, currency: "USD") }
            if productId == "premium" { return (price: 9.99, currency: "EUR") }
            return nil
        }
    }

    override func tearDown() {
        observer.stopObserving()
        observer = nil
        capturingTracker = nil
        super.tearDown()
    }

    func testIgnoresNonPurchasedTransactions() {
        let purchasing = MockTransaction(state: .purchasing, id: "t1", product: "p1")
        let failed = MockTransaction(state: .failed, id: "t2", product: "p2")
        let restored = MockTransaction(state: .restored, id: "t3", product: "p3")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [purchasing, failed, restored])

        XCTAssertTrue(capturingTracker.trackedPurchases.isEmpty)
    }

    func testTracksPurchasedTransactionWithResolvedPrice() {
        let tx = MockTransaction(state: .purchased, id: "tx-100", product: "gems_50")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 1)
        let tracked = capturingTracker.trackedPurchases[0]
        XCTAssertEqual(tracked.productId, "gems_50")
        XCTAssertEqual(tracked.pricePaid, 4.99, accuracy: 0.001)
        XCTAssertEqual(tracked.currency, "USD")
    }

    func testTracksDifferentCurrencies() {
        let tx = MockTransaction(state: .purchased, id: "tx-eur", product: "premium")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 1)
        let tracked = capturingTracker.trackedPurchases[0]
        XCTAssertEqual(tracked.pricePaid, 9.99, accuracy: 0.001)
        XCTAssertEqual(tracked.currency, "EUR")
    }

    func testFallsBackToZeroPriceForUnknownProduct() {
        let tx = MockTransaction(state: .purchased, id: "tx-unknown", product: "no_such_product")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 1)
        let tracked = capturingTracker.trackedPurchases[0]
        XCTAssertEqual(tracked.productId, "no_such_product")
        XCTAssertEqual(tracked.pricePaid, 0.0, accuracy: 0.001)
        XCTAssertEqual(tracked.currency, "USD")
    }

    func testDeduplicatesSameTransactionId() {
        let tx1 = MockTransaction(state: .purchased, id: "tx-dup", product: "gems_50")
        let tx2 = MockTransaction(state: .purchased, id: "tx-dup", product: "gems_50")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx1, tx2])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 1)
    }

    func testDeduplicatesAcrossSeparateCalls() {
        let tx1 = MockTransaction(state: .purchased, id: "tx-dup2", product: "gems_50")
        let tx2 = MockTransaction(state: .purchased, id: "tx-dup2", product: "gems_50")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx1])
        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx2])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 1)
    }

    func testIgnoresTransactionWithoutId() {
        let tx = MockTransaction(state: .purchased, id: nil, product: "item_b")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx])

        XCTAssertTrue(capturingTracker.trackedPurchases.isEmpty)
    }

    func testTracksMultipleDistinctTransactions() {
        let tx1 = MockTransaction(state: .purchased, id: "tx-a", product: "gems_50")
        let tx2 = MockTransaction(state: .purchased, id: "tx-b", product: "premium")

        observer.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [tx1, tx2])

        XCTAssertEqual(capturingTracker.trackedPurchases.count, 2)
        XCTAssertEqual(capturingTracker.trackedPurchases[0].productId, "gems_50")
        XCTAssertEqual(capturingTracker.trackedPurchases[1].productId, "premium")
    }

    func testAutoTrackPurchasesConfigDefaultsToTrue() {
        let config = VibeGrowthConfig(appId: "app", apiKey: "key")
        XCTAssertTrue(config.autoTrackPurchases)
    }

    func testAutoTrackPurchasesConfigCanBeDisabled() {
        let config = VibeGrowthConfig(appId: "app", apiKey: "key", autoTrackPurchases: false)
        XCTAssertFalse(config.autoTrackPurchases)
    }
}

// MARK: - Test doubles

private class CapturingRevenueTracker: RevenueTracker {
    struct TrackedPurchase {
        let pricePaid: Double
        let currency: String
        let productId: String?
    }

    var trackedPurchases: [TrackedPurchase] = []

    override func trackPurchase(pricePaid: Double, currency: String, productId: String? = nil) {
        trackedPurchases.append(TrackedPurchase(pricePaid: pricePaid, currency: currency, productId: productId))
    }
}

private class MockPayment: SKPayment {
    private let _productIdentifier: String

    init(productIdentifier: String) {
        _productIdentifier = productIdentifier
        super.init()
    }

    override var productIdentifier: String { _productIdentifier }
}

private class MockTransaction: SKPaymentTransaction {
    private let _state: SKPaymentTransactionState
    private let _id: String?
    private let _payment: SKPayment

    init(state: SKPaymentTransactionState, id: String?, product: String) {
        _state = state
        _id = id
        _payment = MockPayment(productIdentifier: product)
        super.init()
    }

    override var transactionState: SKPaymentTransactionState { _state }
    override var transactionIdentifier: String? { _id }
    override var payment: SKPayment { _payment }
}
