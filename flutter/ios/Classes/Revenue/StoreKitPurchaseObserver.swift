import Foundation
import StoreKit

class StoreKitPurchaseObserver: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    private let revenueTracker: RevenueTracker
    private let lock = NSLock()
    private var trackedTransactionIds = Set<String>()
    private var productCache = [String: SKProduct]()
    private var pendingProductIds = [String: Set<String>]()

    internal var productPriceResolver: ((_ productId: String) -> (price: Double, currency: String)?)?

    init(revenueTracker: RevenueTracker) {
        self.revenueTracker = revenueTracker
        super.init()
    }

    func startObserving() {
        NSLog("[VibeGrowth] StoreKit purchase observer started (SK1)")
        SKPaymentQueue.default().add(self)
    }

    func stopObserving() {
        SKPaymentQueue.default().remove(self)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions where transaction.transactionState == .purchased {
            guard let transactionId = transaction.transactionIdentifier else { continue }

            lock.lock()
            let alreadyTracked = trackedTransactionIds.contains(transactionId)
            if !alreadyTracked {
                trackedTransactionIds.insert(transactionId)
            }
            lock.unlock()

            if alreadyTracked { continue }

            let productId = transaction.payment.productIdentifier

            if let resolver = productPriceResolver {
                if let resolved = resolver(productId) {
                    revenueTracker.trackPurchase(pricePaid: resolved.price, currency: resolved.currency, productId: productId)
                } else {
                    revenueTracker.trackPurchase(pricePaid: 0, currency: "USD", productId: productId)
                }
                continue
            }

            lock.lock()
            let cachedProduct = productCache[productId]
            lock.unlock()

            if let product = cachedProduct {
                trackFromProduct(product)
            } else {
                lock.lock()
                var ids = pendingProductIds[productId] ?? Set()
                ids.insert(transactionId)
                pendingProductIds[productId] = ids
                lock.unlock()

                let request = SKProductsRequest(productIdentifiers: [productId])
                request.delegate = self
                request.start()
            }
        }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        for product in response.products {
            lock.lock()
            productCache[product.productIdentifier] = product
            let pending = pendingProductIds.removeValue(forKey: product.productIdentifier)
            lock.unlock()

            if pending != nil {
                trackFromProduct(product)
            }
        }

        lock.lock()
        let failedIds = response.invalidProductIdentifiers
        for invalidId in failedIds {
            if pendingProductIds.removeValue(forKey: invalidId) != nil {
                lock.unlock()
                revenueTracker.trackPurchase(pricePaid: 0, currency: "USD", productId: invalidId)
                lock.lock()
            }
        }
        lock.unlock()
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        lock.lock()
        let allPending = pendingProductIds
        pendingProductIds.removeAll()
        lock.unlock()

        for (productId, _) in allPending {
            revenueTracker.trackPurchase(pricePaid: 0, currency: "USD", productId: productId)
        }
    }

    private func trackFromProduct(_ product: SKProduct) {
        let price = product.price.doubleValue
        let currency = product.priceLocale.currencyCode ?? "USD"
        NSLog("[VibeGrowth] Auto-tracked purchase: productId=%@ price=%.2f %@", product.productIdentifier, price, currency)
        revenueTracker.trackPurchase(pricePaid: price, currency: currency, productId: product.productIdentifier)
    }
}
