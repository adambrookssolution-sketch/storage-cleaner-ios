import SwiftUI

@main
struct StorageCleanerApp: App {
    @StateObject private var appState = AppState()

    init() {
        SubscriptionService.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(nil)
        }
    }
}
