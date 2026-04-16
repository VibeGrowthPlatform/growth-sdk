import Foundation

@objc public class VibeGrowthConfig: NSObject {
    @objc public let appId: String
    @objc public let apiKey: String
    @objc public let baseUrl: String
    @objc public let autoTrackPurchases: Bool

    @objc public init(appId: String, apiKey: String, baseUrl: String = "https://api.vibegrowin.ai", autoTrackPurchases: Bool = true) {
        self.appId = appId
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.autoTrackPurchases = autoTrackPurchases
        super.init()
    }
}
