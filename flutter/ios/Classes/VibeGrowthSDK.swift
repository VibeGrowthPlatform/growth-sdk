import Foundation

@objc public class VibeGrowthSDK: NSObject {
    @objc public static let shared = VibeGrowthSDK()

    private static let platform = "ios"
    private static let sdkVersion = "1.0.0"

    private var isInitialized = false
    private var config: VibeGrowthConfig?
    private var apiClient: ApiClient?
    private var identityManager: UserIdentityManager?
    private var revenueTracker: RevenueTracker?

    private override init() {
        super.init()
    }

    @objc public func initialize(appId: String, apiKey: String, completion: ((Bool, String?) -> Void)? = nil) {
        if isInitialized {
            completion?(true, nil)
            return
        }

        let config = VibeGrowthConfig(appId: appId, apiKey: apiKey)
        let apiClient = ApiClient(config: config)
        let store = UserDefaultsStore()
        let identityManager = UserIdentityManager(store: store)
        let revenueTracker = RevenueTracker(apiClient: apiClient, identityManager: identityManager)

        self.config = config
        self.apiClient = apiClient
        self.identityManager = identityManager
        self.revenueTracker = revenueTracker

        DispatchQueue.global(qos: .background).async {
            let deviceId = identityManager.getOrCreateDeviceId()
            let attribution = AdServicesHelper.getAttribution()

            apiClient.postInit(
                deviceId: deviceId,
                platform: VibeGrowthSDK.platform,
                attribution: attribution.isEmpty ? nil : attribution,
                sdkVersion: VibeGrowthSDK.sdkVersion
            ) { [weak self] success, error in
                guard let self = self else { return }
                if success {
                    self.isInitialized = true
                }
                DispatchQueue.main.async {
                    if success {
                        completion?(true, nil)
                    } else {
                        completion?(false, error)
                    }
                }
            }
        }
    }

    @objc public func setUserId(_ userId: String) {
        checkInitialized()
        guard let identityManager = identityManager, let apiClient = apiClient else { return }

        identityManager.setUserId(userId)
        DispatchQueue.global(qos: .background).async {
            let deviceId = identityManager.getOrCreateDeviceId()
            apiClient.postIdentify(deviceId: deviceId, userId: userId, completion: nil)
        }
    }

    @objc public func getUserId() -> String? {
        checkInitialized()
        return identityManager?.getUserId()
    }

    @objc public func trackPurchase(amount: Double, currency: String, productId: String) {
        checkInitialized()
        revenueTracker?.trackPurchase(amount: amount, currency: currency, productId: productId)
    }

    @objc public func trackAdRevenue(source: String, revenue: Double, currency: String) {
        checkInitialized()
        revenueTracker?.trackAdRevenue(source: source, revenue: revenue, currency: currency)
    }

    @objc public func trackSession(sessionStart: String, sessionDurationMs: Int) {
        checkInitialized()
        guard let identityManager = identityManager, let apiClient = apiClient else { return }

        DispatchQueue.global(qos: .background).async {
            let deviceId = identityManager.getOrCreateDeviceId()
            apiClient.postSession(deviceId: deviceId, sessionStart: sessionStart, sessionDurationMs: sessionDurationMs, completion: nil)
        }
    }

    private func checkInitialized() {
        if !isInitialized {
            NSException(name: .internalInconsistencyException, reason: "VibeGrowthSDK is not initialized. Call initialize() first.").raise()
        }
    }
}
