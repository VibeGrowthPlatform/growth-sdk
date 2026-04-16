import Foundation
import XCTest
@testable import VibeGrowthSDK

final class VibeGrowthSdkEndToEndTests: XCTestCase {
    private var testConfig = SdkE2EConfig.load()

    private var sdkBaseUrl: String { simulatorLoopbackUrl(testConfig?.baseUrl ?? ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E_BASE_URL"] ?? "http://127.0.0.1:8000") }
    private var clickHouseUrl: String { simulatorLoopbackUrl(testConfig?.clickHouseUrl ?? ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL"] ?? "http://127.0.0.1:8123") }
    private var clickHouseDatabase: String { testConfig?.clickHouseDatabase ?? ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE"] ?? "scalemonk" }
    private var appId: String { testConfig?.appId ?? ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E_APP_ID"] ?? "sm_app_sdk_e2e" }
    private var apiKey: String { testConfig?.apiKey ?? ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E_API_KEY"] ?? "sk_live_sdk_e2e_local_only" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        testConfig = SdkE2EConfig.load()
        let isEnabled = testConfig?.enabled == true || ProcessInfo.processInfo.environment["VIBEGROWTH_SDK_E2E"] == "1"
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

    func testFullSdkFlowPersistsThroughRealBackend() throws {
        let deviceId = "ios-e2e-\(UUID().uuidString)"
        let userId = "user-\(UUID().uuidString)"
        let productId = "product-\(UUID().uuidString)"
        let firstSessionStart = "2026-04-02T10:00:00+00:00"
        let secondSessionStart = "2026-04-02T10:05:00+00:00"

        UserDefaults(suiteName: "com.vibegrowth.sdk")?.set(deviceId, forKey: "vibegrowth_device_id")

        let initExpectation = expectation(description: "initialize")
        var initError: String?
        VibeGrowthSDK.shared.initialize(appId: appId, apiKey: apiKey, baseUrl: sdkBaseUrl, autoTrackPurchases: false) { success, error in
            if !success {
                initError = error
            }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 20)
        XCTAssertNil(initError)

        try eventuallyEquals(
            "ios",
            query: """
                SELECT platform
                FROM devices FINAL
                WHERE device_id = \(sqlString(deviceId))
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """
        )
        try eventuallyEquals(
            "0.0.1",
            query: """
                SELECT sdk_version
                FROM devices FINAL
                WHERE device_id = \(sqlString(deviceId))
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """
        )

        VibeGrowthSDK.shared.setUserId(userId)
        XCTAssertEqual(VibeGrowthSDK.shared.getUserId(), userId)
        try eventuallyEquals(
            userId,
            query: """
                SELECT ifNull(user_id, '')
                FROM devices FINAL
                WHERE device_id = \(sqlString(deviceId))
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """
        )

        VibeGrowthSDK.shared.trackPurchase(pricePaid: 4.99, currency: "USD", productId: productId)
        try eventuallyEquals(
            productId,
            query: """
                SELECT ifNull(product_id, '')
                FROM revenue_events
                WHERE device_id = \(sqlString(deviceId))
                  AND product_id = \(sqlString(productId))
                ORDER BY received_at DESC
                LIMIT 1
                FORMAT TSVRaw
            """
        )

        VibeGrowthSDK.shared.trackSessionStart(sessionStart: firstSessionStart)
        VibeGrowthSDK.shared.trackSessionStart(sessionStart: secondSessionStart)
        try eventuallyEquals(
            "1",
            query: """
                SELECT count()
                FROM session_events
                WHERE device_id = \(sqlString(deviceId))
                  AND is_first_session = 1
                FORMAT TSVRaw
            """
        )
        try eventuallyEquals(
            "1",
            query: """
                SELECT count()
                FROM session_events
                WHERE device_id = \(sqlString(deviceId))
                  AND is_first_session = 0
                FORMAT TSVRaw
            """
        )

        let configExpectation = expectation(description: "config")
        var configJson: String?
        var configError: String?
        VibeGrowthSDK.shared.getConfig { value, error in
            configJson = value
            configError = error
            configExpectation.fulfill()
        }
        wait(for: [configExpectation], timeout: 20)
        XCTAssertNil(configError)
        XCTAssertEqual(configJson, "{}")
    }

    private func eventuallyEquals(
        _ expected: String,
        query: String,
        timeoutSeconds: TimeInterval = 20,
        pollIntervalSeconds: TimeInterval = 0.5
    ) throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var lastValue = ""
        var lastError: String?

        while Date() < deadline {
            do {
                lastValue = try runClickHouseQuery(query)
                if lastValue == expected {
                    return
                }
            } catch {
                lastError = error.localizedDescription
            }
            Thread.sleep(forTimeInterval: pollIntervalSeconds)
        }

        XCTFail("Timed out waiting for ClickHouse query result. expected=\(expected), lastValue=\(lastValue), lastError=\(lastError ?? "")")
        throw TestError.timeout
    }

    private func runClickHouseQuery(_ query: String) throws -> String {
        var components = URLComponents(string: clickHouseUrl)
        components?.queryItems = [
            URLQueryItem(name: "database", value: clickHouseDatabase),
            URLQueryItem(name: "wait_end_of_query", value: "1"),
        ]
        guard let url = components?.url else {
            throw TestError.invalidURL(clickHouseUrl)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.httpBody = query.data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result = .failure(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(TestError.invalidResponse)
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                result = .failure(TestError.httpFailure(statusCode: httpResponse.statusCode, body: body))
                return
            }

            let body = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            result = .success(body)
        }.resume()

        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            throw TestError.timeout
        }

        guard let result else {
            throw TestError.invalidResponse
        }
        return try result.get()
    }

    private func sqlString(_ value: String) -> String {
        return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    private func simulatorLoopbackUrl(_ value: String) -> String {
        value.replacingOccurrences(of: "http://127.0.0.1:", with: "http://[::1]:")
    }
}

private struct SdkE2EConfig {
    let enabled: Bool
    let appId: String
    let apiKey: String
    let baseUrl: String
    let clickHouseUrl: String
    let clickHouseDatabase: String

    static func load() -> SdkE2EConfig? {
        let url = URL(fileURLWithPath: "/tmp/vibegrowth-sdk-e2e.json")
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return SdkE2EConfig(
            enabled: json["enabled"] as? Bool ?? false,
            appId: json["appId"] as? String ?? "sm_app_sdk_e2e",
            apiKey: json["apiKey"] as? String ?? "sk_live_sdk_e2e_local_only",
            baseUrl: json["baseUrl"] as? String ?? "http://127.0.0.1:8000",
            clickHouseUrl: json["clickHouseUrl"] as? String ?? "http://127.0.0.1:8123",
            clickHouseDatabase: json["clickHouseDatabase"] as? String ?? "scalemonk"
        )
    }
}

private enum TestError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpFailure(statusCode: Int, body: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .invalidResponse:
            return "Invalid response"
        case .httpFailure(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .timeout:
            return "Request timed out"
        }
    }
}
