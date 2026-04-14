import SwiftUI

@main
struct VGExampleApp: App {
    @StateObject private var viewModel = ExampleViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    viewModel.startDefaultFlow()
                }
        }
    }
}
