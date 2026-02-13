import SwiftUI

/// Parent container managing the 4-step onboarding flow with transitions
struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @EnvironmentObject var appState: AppState

    init(permissionService: PermissionService, storageService: StorageAnalysisService) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            permissionService: permissionService,
            storageService: storageService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            OnboardingProgressBar(
                totalSteps: OnboardingStep.totalCount,
                currentStep: viewModel.currentStep.rawValue
            )
            .padding(.horizontal, AppConstants.UI.horizontalPadding)
            .padding(.top, 12)

            // Step content with slide transitions
            ZStack {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView(viewModel: viewModel) {
                        Task { await viewModel.handleWelcomeTap() }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

                case .permission:
                    PermissionStepView(viewModel: viewModel) {
                        viewModel.advanceStep()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

                case .duplicatesTutorial:
                    DuplicatesTutorialStepView(viewModel: viewModel) {
                        viewModel.advanceStep()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

                case .storageOverview:
                    StorageOverviewStepView(viewModel: viewModel) {
                        appState.completeOnboarding()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
        }
        .onAppear {
            viewModel.loadStorageInfo()
        }
    }
}
