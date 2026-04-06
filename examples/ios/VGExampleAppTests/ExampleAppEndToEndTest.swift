import Foundation
import XCTest
@testable import VibeGrowthSDK

/// End-to-end test that exercises the example app's SDK integration
/// against the real local backend.
///
/// Requires:
///   - Backend running at http://[::1]:8000
///   - ClickHouse running at http://[::1]:8123
///   - Seeded e2e app (sm_app_sdk_e2e / sk_live_sdk_e2e_local_only)
///
/// Enable by placing /tmp/vibegrowth-sdk-e2e.json with {"enabled": true, ...}
/// or setting VIBEGROWTH_SDK_E2E=1 environment variable.
final class ExampleAppEndToEndTest: XCTestCase {

    private var baseUrl: String { loadField("baseUrl") ?? "http://[::1]:8000" }
    private var chUrl: String { loadField("clickHouseUrl") ?? "http://[::1]:8123" }
    private var chDb: String { loadField("clickHouseDatabase") ?? "scalemonk" }
    private var appId: String { loadField("appId") ?? "sm_app_sdk_e2e" }
    private var apiKey: String { loadField("apiKey") ?? "sk_live_sdk_e2e_local_only" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let isEnabled = loadBool("enabled") ?? false
            || ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E"] == "1"
        guard isEnabled else {
            throw XCTSkip("SDK real-backend e2e is disabled")
        }
        VibeGrowthSDK.shared.resetForTests()
        VibeGrowthSDK.attributionProviderForTests = { [:] }
    }

    override func tearDownWithError() throws {
        VibeGrowthSDK.shared.resetForTests()
        try super.tearDownWithError()
    }

    func testExampleAppFlowWorksEndToEnd() throws {
        let deviceId = "example-ios-\(UUID().uuidString)"
        let userId = "example-user-\(UUID().uuidString)"
        let productId = "example-product-\(UUID().uuidString)"

        // Pre-set device ID
        UserDefaults(suiteName: "com.vibegrowth.sdk")?.set(deviceId, forKey: "vibegrowth_device_id")

        // 1. Initialize (same as VGExampleApp.init)
        let initExp = expectation(description: "init")
        var initError: String?
        VibeGrowthSDK.shared.initialize(appId: appId, apiKey: apiKey, baseUrl: baseUrl) { success, error in
            if !success { initError = error }
            initExp.fulfill()
        }
        wait(for: [initExp], timeout: 20)
        XCTAssertNil(initError, "Init failed: \(initError ?? "")")

        // Verify device registered
        try eventuallyEquals("ios", query: """
            SELECT platform FROM devices FINAL
            WHERE device_id = \(q(deviceId))
            ORDER BY updated_at DESC LIMIT 1 FORMAT TSVRaw
        """)

        // 2. Set User ID (same as "Set User ID" button)
        VibeGrowthSDK.shared.setUserId(userId)
        XCTAssertEqual(VibeGrowthSDK.shared.getUserId(), userId)

        try eventuallyEquals(userId, query: """
            SELECT ifNull(user_id, '') FROM devices FINAL
            WHERE device_id = \(q(deviceId))
            ORDER BY updated_at DESC LIMIT 1 FORMAT TSVRaw
        """)

        // 3. Track Purchase (same as "Track Purchase" button)
        VibeGrowthSDK.shared.trackPurchase(pricePaid: 4.99, currency: "USD", productId: productId)

        try eventuallyEquals(productId, query: """
            SELECT ifNull(product_id, '') FROM revenue_events
            WHERE device_id = \(q(deviceId)) AND product_id = \(q(productId))
            ORDER BY received_at DESC LIMIT 1 FORMAT TSVRaw
        """)

        // 4. Track Ad Revenue (same as "Track Ad Revenue" button)
        VibeGrowthSDK.shared.trackAdRevenue(source: "admob", revenue: 0.02, currency: "USD")

        try eventuallyEquals("ad_revenue", query: """
            SELECT revenue_type FROM revenue_events
            WHERE device_id = \(q(deviceId)) AND revenue_type = 'ad_revenue'
            ORDER BY received_at DESC LIMIT 1 FORMAT TSVRaw
        """)

        // 5. Track Session (same as "Track Session Start" button)
        VibeGrowthSDK.shared.trackSessionStart(sessionStart: "2026-04-06T10:00:00+00:00")

        try eventuallyEquals("1", query: """
            SELECT count() FROM session_events
            WHERE device_id = \(q(deviceId))
            FORMAT TSVRaw
        """)

        // 6. Get Config (same as "Get Config" button)
        let configExp = expectation(description: "config")
        var configJson: String?
        var configError: String?
        VibeGrowthSDK.shared.getConfig { value, error in
            configJson = value
            configError = error
            configExp.fulfill()
        }
        wait(for: [configExp], timeout: 20)
        XCTAssertNil(configError)
        XCTAssertEqual(configJson, "{}")
    }

    // MARK: - Helpers

    private func eventuallyEquals(_ expected: String, query: String, timeout: TimeInterval = 20) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastValue = ""
        var lastError: String?
        while Date() < deadline {
            do {
                lastValue = try chQuery(query)
                if lastValue == expected { return }
            } catch {
                lastError = error.localizedDescription
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("Timed out. expected=\(expected), lastValue=\(lastValue), lastError=\(lastError ?? "")")
    }

    private func chQuery(_ query: String) throws -> String {
        var components = URLComponents(string: chUrl)
        components?.queryItems = [
            URLQueryItem(name: "database", value: chDb),
            URLQueryItem(name: "wait_end_of_query", value: "1"),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.httpBody = query.data(using: .utf8)
        let sem = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { sem.signal() }
            if let error { result = .failure(error); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                result = .failure(NSError(domain: "CH", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: body]))
                return
            }
            result = .success(data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        }.resume()
        _ = sem.wait(timeout: .now() + 10)
        guard let result else { throw URLError(.timedOut) }
        return try result.get()
    }

    private func q(_ v: String) -> String { "'\(v.replacingOccurrences(of: "'", with: "''"))'" }

    private func loadField(_ field: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/vibegrowth-sdk-e2e.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json[field] as? String
    }

    private func loadBool(_ field: String) -> Bool? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/vibegrowth-sdk-e2e.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json[field] as? Bool
    }
}
