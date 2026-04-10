import Flutter
import Foundation

public class VibeGrowthSdkPlugin: NSObject, FlutterPlugin {
    private var isInitialized = false
    private let exampleBaseUrlKey = "example.last_base_url"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.vibegrowth.sdk/channel", binaryMessenger: registrar.messenger())
        let instance = VibeGrowthSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "initialize":
            guard let appId = args?["appId"] as? String,
                  let apiKey = args?["apiKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "appId and apiKey are required", details: nil))
                return
            }
            let baseUrl = args?["baseUrl"] as? String
            VibeGrowthSDK.shared.initialize(appId: appId, apiKey: apiKey, baseUrl: baseUrl) { [weak self] success, error in
                if success {
                    self?.isInitialized = true
                    result(nil)
                } else {
                    result(FlutterError(code: "INIT_ERROR", message: error, details: nil))
                }
            }

        case "setUserId":
            guard ensureInitialized(result) else { return }
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "userId is required", details: nil))
                return
            }
            VibeGrowthSDK.shared.setUserId(userId)
            result(nil)

        case "getUserId":
            guard ensureInitialized(result) else { return }
            let userId = VibeGrowthSDK.shared.getUserId()
            result(userId)

        case "trackPurchase":
            guard ensureInitialized(result) else { return }
            let pricePaid = (args?["pricePaid"] as? Double) ?? (args?["amount"] as? Double)
            guard let pricePaid,
                  let currency = args?["currency"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "pricePaid and currency are required", details: nil))
                return
            }
            let productId = args?["productId"] as? String
            VibeGrowthSDK.shared.trackPurchase(pricePaid: pricePaid, currency: currency, productId: productId)
            result(nil)

        case "trackAdRevenue":
            guard ensureInitialized(result) else { return }
            guard let source = args?["source"] as? String,
                  let revenue = args?["revenue"] as? Double,
                  let currency = args?["currency"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "source, revenue, and currency are required", details: nil))
                return
            }
            VibeGrowthSDK.shared.trackAdRevenue(source: source, revenue: revenue, currency: currency)
            result(nil)

        case "trackSessionStart", "trackSession":
            guard ensureInitialized(result) else { return }
            guard let sessionStart = args?["sessionStart"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "sessionStart is required", details: nil))
                return
            }
            VibeGrowthSDK.shared.trackSessionStart(sessionStart: sessionStart)
            result(nil)

        case "getConfig":
            guard ensureInitialized(result) else { return }
            VibeGrowthSDK.shared.getConfig { configJson, error in
                if let error {
                    result(FlutterError(code: "CONFIG_ERROR", message: error, details: nil))
                } else {
                    result(configJson)
                }
            }

        case "setExampleBaseUrl":
            let baseUrl = (args?["baseUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let store = UserDefaultsStore()
            store.putString(exampleBaseUrlKey, value: baseUrl)
            result(nil)

        case "getExampleBaseUrl":
            let store = UserDefaultsStore()
            result(store.getString(exampleBaseUrlKey))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ensureInitialized(_ result: FlutterResult) -> Bool {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "VibeGrowthSDK is not initialized. Call initialize() first.", details: nil))
            return false
        }
        return true
    }
}
