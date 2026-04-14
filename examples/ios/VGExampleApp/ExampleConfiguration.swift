import Foundation

enum ExampleConfiguration {
    static let appId = value(
        env: "VIBEGROWTH_SDK_E2E_APP_ID",
        configField: "appId",
        fallback: "sm_app_sdk_e2e"
    )
    static let apiKey = value(
        env: "VIBEGROWTH_SDK_E2E_API_KEY",
        configField: "apiKey",
        fallback: "sk_live_sdk_e2e_local_only"
    )
    static let baseUrl = simulatorLoopbackUrl(
        value(
            env: "VIBEGROWTH_SDK_E2E_BASE_URL",
            configField: "baseUrl",
            fallback: "http://localhost:8000"
        )
    )
    static let controlPort: UInt16 = 8766

    private static func value(env: String, configField: String, fallback: String) -> String {
        if let envValue = ProcessInfo.processInfo.environment[env], !envValue.isEmpty {
            return envValue
        }
        if let configValue = configFieldValue(configField), !configValue.isEmpty {
            return configValue
        }
        return fallback
    }

    private static func configFieldValue(_ field: String) -> String? {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/vibegrowth-sdk-e2e.json")),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json[field] as? String
    }

    static func simulatorLoopbackUrl(_ value: String) -> String {
        value.replacingOccurrences(of: "http://127.0.0.1:", with: "http://[::1]:")
    }
}
