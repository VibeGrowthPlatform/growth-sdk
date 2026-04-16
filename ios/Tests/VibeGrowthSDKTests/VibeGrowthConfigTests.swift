import XCTest
@testable import VibeGrowthSDK

final class VibeGrowthConfigTests: XCTestCase {
    func testDefaultBaseUrl() {
        let config = VibeGrowthConfig(appId: "app", apiKey: "key")

        XCTAssertEqual(config.baseUrl, "https://api.vibegrowin.ai")
    }

    func testExplicitBaseUrlOverride() {
        let config = VibeGrowthConfig(
            appId: "app",
            apiKey: "key",
            baseUrl: "http://localhost:8000"
        )

        XCTAssertEqual(config.baseUrl, "http://localhost:8000")
    }
}
