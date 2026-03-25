import SwiftUI

/// Onboarding Step 2: Photo permission request
/// Shows status after system dialog resolves
struct PermissionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onPermissionHandled: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if viewModel.isRequestingPermission {
                // Waiting state while system dialog is showing
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ColorTokens.primaryBlue)
                Text(NSLocalizedString("permission.waiting", comment: ""))
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
            } else {
                switch viewModel.permissionStatus {
                case .authorized, .limited:
                    // Success state
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(ColorTokens.successGreen)
                        .transition(.scale.combined(with: .opacity))

                    Text(NSLocalizedString("permission.granted", comment: ""))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryText)

                    if viewModel.permissionStatus == .limited {
                        Text(NSLocalizedString("permission.limitedAccess", comment: ""))
                            .font(.system(size: 15))
                            .foregroundColor(ColorTokens.secondaryText)
                    }

                case .denied, .restricted:
                    // Denied state
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(ColorTokens.warningOrange)
                        .transition(.scale.combined(with: .opacity))

                    Text(NSLocalizedString("permission.denied", comment: ""))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryText)

                    Text(NSLocalizedString("permission.deniedDetail", comment: ""))
                        .font(.system(size: 15))
                        .foregroundColor(ColorTokens.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(NSLocalizedString("permission.openSettings", comment: "")) {
                        viewModel.permissionService.openSettings()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 60)

                    Spacer().frame(height: 16)

                    Button(NSLocalizedString("permission.continueAnyway", comment: "")) {
                        onPermissionHandled()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ColorTokens.secondaryText)

                case .notDetermined:
                    EmptyView()
                }
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.permissionStatus)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRequestingPermission)
        .onAppear {
            // If permission is not determined, it was already requested by WelcomeStepView
            // Just wait for the result
            if viewModel.permissionStatus.hasAccess {
                // Already granted - auto-advance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onPermissionHandled()
                }
            }
        }
        .onChange(of: viewModel.permissionStatus) { newStatus in
            if newStatus.hasAccess {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onPermissionHandled()
                }
            }
        }
    }
}

