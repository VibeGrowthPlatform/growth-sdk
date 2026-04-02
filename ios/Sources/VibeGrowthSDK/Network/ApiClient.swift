import Foundation

@objc public class ApiClient: NSObject {
    private let config: VibeGrowthConfig

    @objc public init(config: VibeGrowthConfig) {
        self.config = config
        super.init()
    }

    private func normalizedBaseUrl() -> String {
        return config.baseUrl.hasSuffix("/") ? String(config.baseUrl.dropLast()) : config.baseUrl
    }

    @objc public func post(path: String, body: [String: Any], completion: ((Bool, String?) -> Void)?) {
        guard let url = URL(string: "\(normalizedBaseUrl())\(path)") else {
            completion?(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion?(false, "JSON serialization failed: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion?(false, error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion?(false, "Invalid response")
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                completion?(true, nil)
            } else {
                completion?(false, "HTTP \(httpResponse.statusCode)")
            }
        }.resume()
    }

    public func get(path: String, completion: ((Data?, String?) -> Void)?) {
        guard let url = URL(string: "\(normalizedBaseUrl())\(path)") else {
            completion?(nil, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion?(nil, error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion?(nil, "Invalid response")
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion?(nil, "HTTP \(httpResponse.statusCode)")
                return
            }

            completion?(data, nil)
        }.resume()
    }

    @objc public func postInit(deviceId: String, platform: String, attribution: [String: Any]?, sdkVersion: String, completion: ((Bool, String?) -> Void)?) {
        var body: [String: Any] = [
            "app_id": config.appId,
            "device_id": deviceId,
            "platform": platform,
            "sdk_version": sdkVersion
        ]
        if let attribution = attribution {
            body["attribution"] = attribution
        }
        post(path: ApiEndpoints.initPath, body: body, completion: completion)
    }

    @objc public func postIdentify(deviceId: String, userId: String, completion: ((Bool, String?) -> Void)?) {
        let body: [String: Any] = [
            "app_id": config.appId,
            "device_id": deviceId,
            "user_id": userId
        ]
        post(path: ApiEndpoints.identify, body: body, completion: completion)
    }

    @objc public func postRevenue(deviceId: String, userId: String?, event: [String: Any], completion: ((Bool, String?) -> Void)?) {
        var body = event
        body["app_id"] = config.appId
        body["device_id"] = deviceId
        if let userId = userId {
            body["user_id"] = userId
        }
        post(path: ApiEndpoints.revenue, body: body, completion: completion)
    }

    @objc public func postSession(
        deviceId: String,
        userId: String?,
        sessionStart: String,
        isFirstSession: Bool,
        completion: ((Bool, String?) -> Void)?
    ) {
        var body: [String: Any] = [
            "app_id": config.appId,
            "device_id": deviceId,
            "session_start": sessionStart,
            "is_first_session": isFirstSession
        ]
        if let userId {
            body["user_id"] = userId
        }
        post(path: ApiEndpoints.session, body: body, completion: completion)
    }

    @objc public func getConfig(completion: ((String?, String?) -> Void)?) {
        get(path: ApiEndpoints.config) { data, error in
            if let error {
                completion?(nil, error)
                return
            }

            guard let data else {
                completion?(nil, "Empty response")
                return
            }

            do {
                let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let config = payload?["config"] as? [String: Any] ?? [:]
                let configData = try JSONSerialization.data(withJSONObject: config)
                let configJson = String(data: configData, encoding: .utf8) ?? "{}"
                completion?(configJson, nil)
            } catch {
                completion?(nil, "JSON parsing failed: \(error.localizedDescription)")
            }
        }
    }
}
