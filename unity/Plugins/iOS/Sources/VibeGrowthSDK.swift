import Foundation
import StoreKit

@objc public class VibeGrowthSDK: NSObject {
    @objc public static let shared = VibeGrowthSDK()

    private static let storeSuiteName = "com.vibegrowth.sdk"
    private static let platform = "ios"
    private static let sdkVersion = "2.1.0"
    private static let firstSessionKey = "vibegrowth_has_tracked_first_session"

    internal static var attributionProviderForTests: (() -> [String: Any])?

    private var isInitialized = false
    private var config: VibeGrowthConfig?
    private var apiClient: ApiClient?
    private var identityManager: UserIdentityManager?
    private var revenueTracker: RevenueTracker?
    private var store: UserDefaultsStore?
    private let sessionTrackingLock = NSLock()
    private var sk1Observer: StoreKitPurchaseObserver?
    private var sk2Observer: Any?

    private override init() {
        super.init()
    }

    internal func resetForTests() {
        isInitialized = false
        config = nil
        apiClient = nil
        identityManager = nil
        revenueTracker = nil
        store = nil
        sk1Observer?.stopObserving()
        sk1Observer = nil
        if #available(iOS 15, *) {
            (sk2Observer as? StoreKit2PurchaseObserver)?.stopObserving()
        }
        sk2Observer = nil
        VibeGrowthSDK.attributionProviderForTests = nil
        UserDefaults(suiteName: VibeGrowthSDK.storeSuiteName)?.removePersistentDomain(forName: VibeGrowthSDK.storeSuiteName)
    }

    @objc(initializeWithAppId:apiKey:completion:)
    public func initialize(appId: String, apiKey: String, completion: ((Bool, String?) -> Void)? = nil) {
        initialize(appId: appId, apiKey: apiKey, baseUrl: nil, autoTrackPurchases: true, completion: completion)
    }

    @objc(initializeWithAppId:apiKey:baseUrl:completion:)
    public func initialize(appId: String, apiKey: String, baseUrl: String?, completion: ((Bool, String?) -> Void)? = nil) {
        initialize(appId: appId, apiKey: apiKey, baseUrl: baseUrl, autoTrackPurchases: true, completion: completion)
    }

    @objc(initializeWithAppId:apiKey:baseUrl:autoTrackPurchases:completion:)
    public func initialize(appId: String, apiKey: String, baseUrl: String?, autoTrackPurchases: Bool, completion: ((Bool, String?) -> Void)? = nil) {
        if isInitialized {
            completion?(true, nil)
            return
        }

        let config: VibeGrowthConfig
        if let baseUrl, !baseUrl.isEmpty {
            config = VibeGrowthConfig(appId: appId, apiKey: apiKey, baseUrl: baseUrl, autoTrackPurchases: autoTrackPurchases)
        } else {
            config = VibeGrowthConfig(appId: appId, apiKey: apiKey, autoTrackPurchases: autoTrackPurchases)
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
            let attribution = VibeGrowthSDK.attributionProviderForTests?() ?? AdServicesHelper.getAttribution()

            apiClient.postInit(
                deviceId: deviceId,
                platform: VibeGrowthSDK.platform,
                attribution: attribution.isEmpty ? nil : attribution,
                sdkVersion: VibeGrowthSDK.sdkVersion
            ) { [weak self] success, error in
                guard let self = self else { return }
                if success {
                    self.isInitialized = true
                    if config.autoTrackPurchases {
                        self.startPurchaseObservers(revenueTracker: revenueTracker)
                    }
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

        sessionTrackingLock.lock()
        let hasTrackedFirstSession = store.getBool(VibeGrowthSDK.firstSessionKey)
        if !hasTrackedFirstSession {
            store.putBool(VibeGrowthSDK.firstSessionKey, value: true)
        }
        sessionTrackingLock.unlock()
        let isFirstSession = !hasTrackedFirstSession

        DispatchQueue.global(qos: .background).async {
            let deviceId = identityManager.getOrCreateDeviceId()
            let userId = identityManager.getUserId()
            apiClient.postSession(
                deviceId: deviceId,
                userId: userId,
                sessionStart: sessionStart,
                isFirstSession: isFirstSession
            ) { success, _ in
                if !success, isFirstSession {
                    self.sessionTrackingLock.lock()
                    store.putBool(VibeGrowthSDK.firstSessionKey, value: false)
                    self.sessionTrackingLock.unlock()
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

    private func startPurchaseObservers(revenueTracker: RevenueTracker) {
        if #available(iOS 15, *) {
            let observer = StoreKit2PurchaseObserver(revenueTracker: revenueTracker)
            observer.startObserving()
            sk2Observer = observer
        } else {
            let observer = StoreKitPurchaseObserver(revenueTracker: revenueTracker)
            observer.startObserving()
            sk1Observer = observer
        }
    }

    private func checkInitialized() {
        if !isInitialized {
            NSException(name: .internalInconsistencyException, reason: "VibeGrowthSDK is not initialized. Call initialize() first.").raise()
        }
    }
}
