import SwiftUI
import VibeGrowthSDK

@main
struct VGExampleApp: App {
    @StateObject private var viewModel = ExampleViewModel()

    init() {
        VibeGrowthSDK.shared.initialize(
            appId: "sm_app_example",
            apiKey: "sk_live_example_key",
            baseUrl: "http://localhost:8000"
        ) { success, error in
            if let error {
                print("[VGExample] Init failed: \(error)")
            } else {
                print("[VGExample] SDK initialized: \(success)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
