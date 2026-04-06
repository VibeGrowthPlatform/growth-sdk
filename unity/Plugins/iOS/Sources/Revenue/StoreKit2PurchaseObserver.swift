import Foundation
import StoreKit

@available(iOS 15, *)
class StoreKit2PurchaseObserver {
    private let revenueTracker: RevenueTracker
    private var updateTask: Task<Void, Never>?
    private let lock = NSLock()
    private var trackedTransactionIds = Set<UInt64>()

    init(revenueTracker: RevenueTracker) {
        self.revenueTracker = revenueTracker
    }

    func startObserving() {
        NSLog("[VibeGrowth] StoreKit purchase observer started (SK2)")
        updateTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                guard case .verified(let transaction) = result else { continue }

                self.lock.lock()
                let alreadyTracked = self.trackedTransactionIds.contains(transaction.id)
                if !alreadyTracked {
                    self.trackedTransactionIds.insert(transaction.id)
                }
                self.lock.unlock()

                if alreadyTracked { continue }

                let price: Double
                let currency: String

                if #available(iOS 16, *) {
                    price = NSDecimalNumber(decimal: transaction.price ?? 0).doubleValue
                    currency = transaction.currency?.identifier ?? "USD"
                } else {
                    price = NSDecimalNumber(decimal: transaction.price ?? 0).doubleValue
                    currency = transaction.currencyCode ?? "USD"
                }

                NSLog("[VibeGrowth] Auto-tracked purchase (SK2): productId=%@ price=%.2f %@", transaction.productID, price, currency)
                self.revenueTracker.trackPurchase(
                    pricePaid: price,
                    currency: currency,
                    productId: transaction.productID
                )
            }
        }
    }

    func stopObserving() {
        updateTask?.cancel()
        updateTask = nil
    }
}
