import Foundation

@objc public class RevenueTracker: NSObject {
    private let apiClient: ApiClient
    private let identityManager: UserIdentityManager

    @objc public init(apiClient: ApiClient, identityManager: UserIdentityManager) {
        self.apiClient = apiClient
        self.identityManager = identityManager
        super.init()
    }

    @objc public func trackPurchase(pricePaid: Double, currency: String, productId: String? = nil) {
        var event: [String: Any] = [
            "revenue_type": "purchase",
            "amount": pricePaid,
            "currency": currency,
        ]
        if let productId {
            event["product_id"] = productId
        }
        postRevenue(event: event)
    }

    @objc public func trackAdRevenue(source: String, revenue: Double, currency: String) {
        let event: [String: Any] = [
            "revenue_type": "ad_revenue",
            "amount": revenue,
            "currency": currency,
            "ad_source": source
        ]
        postRevenue(event: event)
    }

    private func postRevenue(event: [String: Any]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let deviceId = self.identityManager.getOrCreateDeviceId()
            let userId = self.identityManager.getUserId()
            self.apiClient.postRevenue(deviceId: deviceId, userId: userId, event: event, completion: nil)
        }
    }
}
