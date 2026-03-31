import SwiftUI

/// Root router: shows onboarding or main tab view based on app state
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    private let permissionService = PermissionService()
    private let storageService = StorageAnalysisService()

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView(
                    permissionService: permissionService,
                    storageService: storageService
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.hasCompletedOnboarding)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                permissionService.refreshStatus()
                SubscriptionService.shared.revalidateOnForeground()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // On memory pressure: post notification so active ViewModels can clear caches
            NotificationCenter.default.post(name: .memoryWarningClearCaches, object: nil)
        }
    }
}
