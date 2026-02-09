import SwiftUI

/// Onboarding Step 1: Welcome screen with storage bar
/// Matches Screenshot_2 from reference app
struct WelcomeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // Title
            Text("Bem-vindo ao\nStorageCleaner")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(ColorTokens.primaryText)

            Spacer().frame(height: 50)

            // Icons row: Fotos + iCloud
            HStack(spacing: 60) {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: AppConstants.UI.iconSize, height: AppConstants.UI.iconSize)
                    Text("Fotos")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ColorTokens.primaryText)
                }

                VStack(spacing: 10) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "3F9BFF"))
                        .frame(width: AppConstants.UI.iconSize, height: AppConstants.UI.iconSize)
                    Text("iCloud")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ColorTokens.primaryText)
                }
            }

            Spacer().frame(height: 36)

            // Storage bar
            StorageBarView(
                usedBytes: viewModel.storageInfo.usedBytes,
                totalBytes: viewModel.storageInfo.totalBytes
            )
            .padding(.horizontal, 50)

            Spacer()

            // Privacy text
            VStack(spacing: 6) {
                Text("O StorageCleaner precisa ter acesso às Fotos para liberar armazenamento. ")
                    .foregroundColor(ColorTokens.secondaryText)
                + Text("Queremos fornecer transparência e proteger sua privacidade. Ao iniciar, você concorda com nossos")
                    .foregroundColor(ColorTokens.tertiaryText)
            }
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)

            Spacer().frame(height: 6)

            // Terms links
            HStack(spacing: 4) {
                Button(action: { viewModel.openTermsOfUse() }) {
                    Text("Termos de Uso")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTokens.primaryText)
                        .underline()
                }
                Text("e nossa")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.tertiaryText)
                Button(action: { viewModel.openPrivacyPolicy() }) {
                    Text("Política de Privacidade")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTokens.primaryText)
                        .underline()
                }
                Text(".")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTokens.tertiaryText)
            }

            Spacer().frame(height: 24)

            // Primary button
            Button("Começar") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.horizontalPadding)

            Spacer().frame(height: 30)
        }
    }
}
