import SwiftUI

@main
struct StorageCleanerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(nil) // supports both light and dark
        }
    }
}
