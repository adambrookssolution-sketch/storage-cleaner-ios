import SwiftUI
import Combine

/// Manages onboarding page state, permission requests, storage info, and tutorial animation
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentStep: OnboardingStep = .welcome
    @Published var storageInfo: StorageInfo = .placeholder
    @Published var permissionStatus: PhotoPermissionStatus = .notDetermined
    @Published var isRequestingPermission = false
    @Published var tutorialPhase: TutorialPhase = .showPairs

    enum TutorialPhase: Equatable {
        case showPairs         // Step 1: show 3 pairs side by side
        case animateSelection  // Step 2: checkmarks appear on duplicates
        case animateRemoval    // Step 3: duplicates slide away
    }

    // MARK: - Dependencies
    let permissionService: PermissionService
    private let storageService: StorageAnalysisService
    private var cancellables = Set<AnyCancellable>()

    init(permissionService: PermissionService, storageService: StorageAnalysisService) {
        self.permissionService = permissionService
        self.storageService = storageService

        // Bind permission status from service
        permissionService.$status
            .assign(to: &$permissionStatus)
    }

    // MARK: - Actions

    func loadStorageInfo() {
        storageInfo = storageService.getDeviceStorageInfo()
    }

    func requestPhotoPermission() async {
        isRequestingPermission = true
        await permissionService.requestAccess()
        isRequestingPermission = false
    }

    func advanceStep() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextIndex
        }
    }

    func goToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
    }

    /// Called after "Começar" on welcome screen — triggers permission then advances
    func handleWelcomeTap() async {
        await requestPhotoPermission()
        if permissionStatus.hasAccess {
            advanceStep()
            // Skip the permission step and go directly to duplicates tutorial
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.advanceStep()
            }
        } else {
            advanceStep() // Go to permission step to show denied state
        }
    }

    /// Starts the animated tutorial on the duplicates step
    func startDuplicateTutorial() {
        tutorialPhase = .showPairs

        // Phase 1 -> 2: checkmarks appear after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Onboarding.tutorialSelectionDelay) { [weak self] in
            withAnimation(.easeInOut(duration: 0.6)) {
                self?.tutorialPhase = .animateSelection
            }
        }

        // Phase 2 -> 3: duplicates slide away
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Onboarding.tutorialRemovalDelay) { [weak self] in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self?.tutorialPhase = .animateRemoval
            }
        }
    }

    /// Opens iOS Terms of Use URL
    func openTermsOfUse() {
        guard let url = URL(string: AppConstants.URLs.termsOfUse) else { return }
        UIApplication.shared.open(url)
    }

    /// Opens Privacy Policy URL
    func openPrivacyPolicy() {
        guard let url = URL(string: AppConstants.URLs.privacyPolicy) else { return }
        UIApplication.shared.open(url)
    }
}
