import SwiftUI

@main
struct VortexCleanerApp: App {
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
