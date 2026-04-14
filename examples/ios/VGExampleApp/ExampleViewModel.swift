import Combine
import Foundation
import VibeGrowthSDK

final class ExampleViewModel: ObservableObject {
    @Published var logMessages: [LogEntry] = []
    @Published private(set) var initStatus = "idle"
    @Published private(set) var baseUrl = ExampleConfiguration.baseUrl
    @Published private(set) var userId: String?
    @Published private(set) var configJson: String?
    @Published private(set) var configError: String?
    @Published private(set) var commandCount = 0
    @Published private(set) var lastCommand: CommandRecord?
    @Published private(set) var controlServerError: String?

    private var controlServer: ExampleControlServer?
    private var isControlServerStarted = false

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String
    }

    struct CommandRecord {
        let command: String
        let status: String
        let detail: String?
        let timestamp: Date
    }

    // MARK: - SDK Actions

    func startDefaultFlow() {
        initialize()
        startControlServer()
    }

    func initialize(
        appId: String = ExampleConfiguration.appId,
        apiKey: String = ExampleConfiguration.apiKey,
        baseUrl: String = ExampleConfiguration.baseUrl,
        completion: ((Bool, String?) -> Void)? = nil
    ) {
        if initStatus == "ready" {
            if baseUrl != self.baseUrl {
                let error = "SDK already initialized; restart the app to change Base URL."
                log("initialize() skipped: \(error)")
                completion?(false, error)
            } else {
                completion?(true, nil)
            }
            return
        }
        guard initStatus != "initializing" else {
            completion?(false, "SDK initialization is already running")
            return
        }

        self.baseUrl = baseUrl
        initStatus = "initializing"
        configJson = nil
        configError = nil
        log("initialize(baseUrl: \(baseUrl))")

        VibeGrowthSDK.shared.initialize(appId: appId, apiKey: apiKey, baseUrl: baseUrl) { [weak self] success, error in
            guard let self else { return }
            self.initStatus = success ? "ready" : "failed"
            if let error {
                self.log("initialize() error: \(error)")
            } else {
                self.log("SDK initialized")
            }
            completion?(success, error)
        }
    }

    func setUserId() {
        let userId = "user-\(Int(Date().timeIntervalSince1970))"
        setUserId(userId)
    }

    func setUserId(_ userId: String) {
        VibeGrowthSDK.shared.setUserId(userId)
        let retrieved = VibeGrowthSDK.shared.getUserId() ?? "nil"
        self.userId = retrieved == "nil" ? nil : retrieved
        log("setUserId(\"\(userId)\")")
        log("getUserId() = \(retrieved)")
    }

    func getUserId() {
        let userId = VibeGrowthSDK.shared.getUserId() ?? "nil"
        self.userId = userId == "nil" ? nil : userId
        log("getUserId() = \(userId)")
    }

    func trackPurchase(pricePaid: Double = 4.99, currency: String = "USD", productId: String = "gem_pack_100") {
        VibeGrowthSDK.shared.trackPurchase(pricePaid: pricePaid, currency: currency, productId: productId)
        log("trackPurchase(\(pricePaid), \(currency), \(productId))")
    }

    func trackAdRevenue(source: String = "admob", revenue: Double = 0.02, currency: String = "USD") {
        VibeGrowthSDK.shared.trackAdRevenue(source: source, revenue: revenue, currency: currency)
        log("trackAdRevenue(\(source), \(revenue), \(currency))")
    }

    func trackSessionStart(sessionStart: String? = nil) {
        let resolved = sessionStart ?? ISO8601DateFormatter().string(from: Date())
        VibeGrowthSDK.shared.trackSessionStart(sessionStart: resolved)
        log("trackSessionStart(\(resolved))")
    }

    func getConfig(completion: ((String?, String?) -> Void)? = nil) {
        log("getConfig() - requesting...")
        VibeGrowthSDK.shared.getConfig { [weak self] configJson, error in
            DispatchQueue.main.async {
                if let error {
                    self?.configError = error
                    self?.log("getConfig() error: \(error)")
                } else {
                    self?.configJson = configJson
                    self?.configError = nil
                    self?.log("getConfig() = \(configJson ?? "nil")")
                }
                completion?(configJson, error)
            }
        }
    }

    func clearLog() {
        logMessages.removeAll()
    }

    // MARK: - Control Server

    func startControlServer() {
        guard !isControlServerStarted else { return }
        isControlServerStarted = true
        let server = ExampleControlServer(port: ExampleConfiguration.controlPort)
        controlServer = server
        server.start(handler: { [weak self] request, completion in
            DispatchQueue.main.async {
                self?.handleControlRequest(request, completion: completion)
            }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.controlServerError = nil
                    self?.log("control server listening on port \(ExampleConfiguration.controlPort)")
                case .failure(let error):
                    self?.controlServerError = error.localizedDescription
                    self?.log("control server failed: \(error.localizedDescription)")
                }
            }
        })
    }

    func statusPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "ok": true,
            "initStatus": initStatus,
            "baseUrl": baseUrl,
            "commandCount": commandCount,
            "controlPort": Int(ExampleConfiguration.controlPort),
        ]
        if let userId {
            payload["userId"] = userId
        }
        if let configJson {
            payload["config"] = configJson
        }
        if let controlServerError {
            payload["controlServerError"] = controlServerError
        }
        if let lastCommand {
            var commandPayload: [String: Any] = [
                "command": lastCommand.command,
                "status": lastCommand.status,
                "timestamp": ISO8601DateFormatter().string(from: lastCommand.timestamp),
            ]
            if let detail = lastCommand.detail {
                commandPayload["detail"] = detail
            }
            payload["lastCommand"] = commandPayload
        }
        return payload
    }

    private func handleControlRequest(_ request: ControlRequest, completion: @escaping (ControlResponse) -> Void) {
        if request.path == "/status" {
            completion(ControlResponse(statusCode: 200, body: statusPayload()))
            return
        }

        let startedAt = Date()
        commandCount += 1
        log("automation received: \(request.command)")

        let finish: (String, String?, String?, [String: Any]) -> Void = { [weak self] status, detail, error, data in
            guard let self else { return }
            self.lastCommand = CommandRecord(command: request.command, status: status, detail: detail, timestamp: Date())
            var body: [String: Any] = [
                "ok": status == "completed",
                "command": request.command,
                "status": status,
                "data": data,
                "rawUrl": request.rawUrl,
                "startedAt": ISO8601DateFormatter().string(from: startedAt),
                "finishedAt": ISO8601DateFormatter().string(from: Date()),
                "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000),
                "state": self.statusPayload(),
            ]
            if let detail {
                body["detail"] = detail
            }
            if let error {
                body["error"] = error
            }
            let statusCode = status == "completed" ? 200 : (status == "ignored" ? 400 : 500)
            completion(ControlResponse(statusCode: statusCode, body: body))
        }

        switch request.command {
        case "initialize":
            let resolvedBaseUrl = request.params["base_url"] ?? request.params["baseUrl"] ?? request.params["url"] ?? baseUrl
            let resolvedAppId = request.params["app_id"] ?? request.params["appId"] ?? ExampleConfiguration.appId
            let resolvedApiKey = request.params["api_key"] ?? request.params["apiKey"] ?? ExampleConfiguration.apiKey
            initialize(appId: resolvedAppId, apiKey: resolvedApiKey, baseUrl: resolvedBaseUrl) { success, error in
                finish(success ? "completed" : "failed", "init=\(self.initStatus) baseUrl=\(self.baseUrl)", error, [
                    "initStatus": self.initStatus,
                    "baseUrl": self.baseUrl,
                ])
            }
        case "set-user-id":
            ensureInitialized { [weak self] error in
                guard let self else { return }
                if let error {
                    finish("failed", error, error, [:])
                    return
                }
                let requested = request.params["user_id"] ?? request.params["userId"] ?? "user-\(Int(Date().timeIntervalSince1970))"
                self.setUserId(requested)
                finish("completed", "userId=\(self.userId ?? requested)", nil, ["userId": self.userId ?? requested])
            }
        case "track-purchase":
            ensureInitialized { [weak self] error in
                guard let self else { return }
                if let error {
                    finish("failed", error, error, [:])
                    return
                }
                let amount = Double(request.params["amount"] ?? "") ?? 4.99
                let currency = request.params["currency"] ?? "USD"
                let productId = request.params["product_id"] ?? request.params["productId"] ?? "gem_pack_100"
                self.trackPurchase(pricePaid: amount, currency: currency, productId: productId)
                finish("completed", "purchase=\(amount) \(currency) productId=\(productId)", nil, [
                    "amount": amount,
                    "currency": currency,
                    "productId": productId,
                ])
            }
        case "track-ad-revenue":
            ensureInitialized { [weak self] error in
                guard let self else { return }
                if let error {
                    finish("failed", error, error, [:])
                    return
                }
                let source = request.params["source"] ?? "admob"
                let revenue = Double(request.params["revenue"] ?? "") ?? 0.02
                let currency = request.params["currency"] ?? "USD"
                self.trackAdRevenue(source: source, revenue: revenue, currency: currency)
                finish("completed", "adRevenue=\(revenue) \(currency) source=\(source)", nil, [
                    "source": source,
                    "revenue": revenue,
                    "currency": currency,
                ])
            }
        case "track-session-start":
            ensureInitialized { [weak self] error in
                guard let self else { return }
                if let error {
                    finish("failed", error, error, [:])
                    return
                }
                let sessionStart = request.params["session_start"] ?? request.params["sessionStart"]
                self.trackSessionStart(sessionStart: sessionStart)
                finish("completed", "sessionStart=\(sessionStart ?? "(now)")", nil, ["sessionStart": sessionStart ?? ""])
            }
        case "get-config":
            ensureInitialized { [weak self] error in
                guard let self else { return }
                if let error {
                    finish("failed", error, error, [:])
                    return
                }
                self.getConfig { configJson, error in
                    finish(error == nil ? "completed" : "failed", "configLoaded=\(configJson != nil)", error, [
                        "config": configJson ?? "",
                    ])
                }
            }
        case "refresh":
            userId = VibeGrowthSDK.shared.getUserId()
            finish("completed", "init=\(initStatus) baseUrl=\(baseUrl) userId=\(userId ?? "(none)")", nil, statusPayload())
        default:
            finish("ignored", "Command not supported", nil, [:])
        }
    }

    private func ensureInitialized(completion: @escaping (String?) -> Void) {
        if initStatus == "ready" {
            completion(nil)
            return
        }
        initialize { success, error in
            completion(success ? nil : (error ?? "SDK initialization failed"))
        }
    }

    // MARK: - Private

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let entry = LogEntry(timestamp: timestamp, message: message)
        logMessages.append(entry)
        print("[VGExample] \(message)")
    }
}
