import Foundation

@objc public class VibeGrowthConfig: NSObject {
    @objc public let appId: String
    @objc public let apiKey: String
    @objc public let baseUrl: String

    @objc public init(appId: String, apiKey: String, baseUrl: String = "https://api.vibegrowth.com") {
        self.appId = appId
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        super.init()
    }
}
