import UIKit
import VibeGrowthSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        VibeGrowthSDK.shared.initialize(
            appId: "your-app-id",
            apiKey: "your-api-key",
            baseUrl: "https://api.vibegrowth.com"
        ) { success, error in
            if let error {
                print("Vibe Growth init failed: \(error)")
            } else {
                print("Vibe Growth initialized: \(success)")
            }
        }

        return true
    }
}
