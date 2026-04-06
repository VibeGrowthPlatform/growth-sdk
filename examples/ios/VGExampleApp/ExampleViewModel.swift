import Foundation
import VibeGrowthSDK

final class ExampleViewModel: ObservableObject {
    @Published var logMessages: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String
    }

    // MARK: - SDK Actions

    func setUserId() {
        let userId = "user-\(Int(Date().timeIntervalSince1970))"
        VibeGrowthSDK.shared.setUserId(userId)
        let retrieved = VibeGrowthSDK.shared.getUserId() ?? "nil"
        log("setUserId(\"\(userId)\")")
        log("getUserId() = \(retrieved)")
    }

    func getUserId() {
        let userId = VibeGrowthSDK.shared.getUserId() ?? "nil"
        log("getUserId() = \(userId)")
    }

    func trackPurchase() {
        VibeGrowthSDK.shared.trackPurchase(pricePaid: 4.99, currency: "USD", productId: "gem_pack_100")
        log("trackPurchase(4.99, USD, gem_pack_100)")
    }

    func trackAdRevenue() {
        VibeGrowthSDK.shared.trackAdRevenue(source: "admob", revenue: 0.02, currency: "USD")
        log("trackAdRevenue(admob, 0.02, USD)")
    }

    func trackSessionStart() {
        let now = ISO8601DateFormatter().string(from: Date())
        VibeGrowthSDK.shared.trackSessionStart(sessionStart: now)
        log("trackSessionStart(\(now))")
    }

    func getConfig() {
        log("getConfig() - requesting...")
        VibeGrowthSDK.shared.getConfig { [weak self] configJson, error in
            DispatchQueue.main.async {
                if let error {
                    self?.log("getConfig() error: \(error)")
                } else {
                    self?.log("getConfig() = \(configJson ?? "nil")")
                }
            }
        }
    }

    func clearLog() {
        logMessages.removeAll()
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
