import SwiftUI

/// Global app state that persists across the session.
/// Controls onboarding completion and acts as the single source of truth for navigation routing.
@MainActor
final class AppState: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @Published var isScanning = false
    @Published var showSettings = false

    func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }

    /// Reset onboarding (for testing purposes)
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
