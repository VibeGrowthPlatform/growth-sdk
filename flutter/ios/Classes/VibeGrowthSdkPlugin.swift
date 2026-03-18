import Flutter

public class VibeGrowthSdkPlugin: NSObject, FlutterPlugin {

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
            VibeGrowthSDK.shared.initialize(appId: appId, apiKey: apiKey) { success, error in
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "INIT_ERROR", message: error, details: nil))
                }
            }

        case "setUserId":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "userId is required", details: nil))
                return
            }
            VibeGrowthSDK.shared.setUserId(userId)
            result(nil)

        case "getUserId":
            let userId = VibeGrowthSDK.shared.getUserId()
            result(userId)

        case "trackPurchase":
            guard let amount = args?["amount"] as? Double,
                  let currency = args?["currency"] as? String,
                  let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "amount, currency, and productId are required", details: nil))
                return
            }
            VibeGrowthSDK.shared.trackPurchase(amount: amount, currency: currency, productId: productId)
            result(nil)

        case "trackAdRevenue":
            guard let source = args?["source"] as? String,
                  let revenue = args?["revenue"] as? Double,
                  let currency = args?["currency"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "source, revenue, and currency are required", details: nil))
                return
            }
            VibeGrowthSDK.shared.trackAdRevenue(source: source, revenue: revenue, currency: currency)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
