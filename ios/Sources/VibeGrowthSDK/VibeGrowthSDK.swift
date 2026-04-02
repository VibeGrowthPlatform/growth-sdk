import Foundation

@objc public class VibeGrowthSDK: NSObject {
    @objc public static let shared = VibeGrowthSDK()

    private static let platform = "ios"
    private static let sdkVersion = "2.1.0"
    private static let firstSessionKey = "vibegrowth_has_tracked_first_session"

    private var isInitialized = false
    private var config: VibeGrowthConfig?
    private var apiClient: ApiClient?
    private var identityManager: UserIdentityManager?
    private var revenueTracker: RevenueTracker?
    private var store: UserDefaultsStore?

    private override init() {
        super.init()
    }

    @objc(initializeWithAppId:apiKey:completion:)
    public func initialize(appId: String, apiKey: String, completion: ((Bool, String?) -> Void)? = nil) {
        initialize(appId: appId, apiKey: apiKey, baseUrl: nil, completion: completion)
    }

    @objc(initializeWithAppId:apiKey:baseUrl:completion:)
    public func initialize(appId: String, apiKey: String, baseUrl: String?, completion: ((Bool, String?) -> Void)? = nil) {
        if isInitialized {
            completion?(true, nil)
            return
        }

        let config: VibeGrowthConfig
        if let baseUrl, !baseUrl.isEmpty {
            config = VibeGrowthConfig(appId: appId, apiKey: apiKey, baseUrl: baseUrl)
        } else {
            config = VibeGrowthConfig(appId: appId, apiKey: apiKey)
        }
        let apiClient = ApiClient(config: config)
        let store = UserDefaultsStore()
        let identityManager = UserIdentityManager(store: store)
        let revenueTracker = RevenueTracker(apiClient: apiClient, identityManager: identityManager)

        self.config = config
        self.apiClient = apiClient
        self.identityManager = identityManager
        self.revenueTracker = revenueTracker
        self.store = store

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

    @objc public func trackPurchase(pricePaid: Double, currency: String, productId: String? = nil) {
        checkInitialized()
        revenueTracker?.trackPurchase(pricePaid: pricePaid, currency: currency, productId: productId)
    }

    @objc(trackPurchaseWithAmount:currency:productId:)
    public func trackPurchase(amount: Double, currency: String, productId: String) {
        trackPurchase(pricePaid: amount, currency: currency, productId: productId)
    }

    @objc public func trackAdRevenue(source: String, revenue: Double, currency: String) {
        checkInitialized()
        revenueTracker?.trackAdRevenue(source: source, revenue: revenue, currency: currency)
    }

    @objc public func trackSessionStart(sessionStart: String) {
        checkInitialized()
        guard
            let identityManager = identityManager,
            let apiClient = apiClient,
            let store = store
        else { return }

        DispatchQueue.global(qos: .background).async {
            let deviceId = identityManager.getOrCreateDeviceId()
            let userId = identityManager.getUserId()
            let isFirstSession = !store.getBool(VibeGrowthSDK.firstSessionKey)
            apiClient.postSession(
                deviceId: deviceId,
                userId: userId,
                sessionStart: sessionStart,
                isFirstSession: isFirstSession
            ) { success, _ in
                if success && isFirstSession {
                    store.putBool(VibeGrowthSDK.firstSessionKey, value: true)
                }
            }
        }
    }

    @objc(trackSessionWithSessionStart:sessionDurationMs:)
    public func trackSession(sessionStart: String, sessionDurationMs: Int) {
        _ = sessionDurationMs
        trackSessionStart(sessionStart: sessionStart)
    }

    @objc public func getConfig(completion: ((String?, String?) -> Void)? = nil) {
        checkInitialized()
        guard let apiClient = apiClient else {
            completion?(nil, "VibeGrowthSDK is not initialized. Call initialize() first.")
            return
        }

        apiClient.getConfig { configJson, error in
            DispatchQueue.main.async {
                completion?(configJson, error)
            }
        }
    }

    private func checkInitialized() {
        if !isInitialized {
            NSException(name: .internalInconsistencyException, reason: "VibeGrowthSDK is not initialized. Call initialize() first.").raise()
        }
    }
}
