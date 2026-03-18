import Foundation

@objc public class ApiClient: NSObject {
    private let config: VibeGrowthConfig

    @objc public init(config: VibeGrowthConfig) {
        self.config = config
        super.init()
    }

    @objc public func post(path: String, body: [String: Any], completion: ((Bool, String?) -> Void)?) {
        guard let url = URL(string: "\(config.baseUrl)\(path)") else {
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
}
