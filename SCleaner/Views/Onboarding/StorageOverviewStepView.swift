import SwiftUI

/// Onboarding Step 4: Storage breakdown overview
/// Matches Screenshot_8 from reference app
struct StorageOverviewStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    /// Storage category breakdown (estimated proportions)
    private var storageCategories: [(name: String, color: Color, ratio: CGFloat)] {
        let info = viewModel.storageInfo
        let usageRatio = info.usageRatio
        let photosRatio = info.photoLibraryRatio > 0 ? info.photoLibraryRatio : usageRatio * 0.55
        let remaining = max(0, usageRatio - photosRatio)
        return [
            ("Fotos", ColorTokens.destructiveRed, photosRatio),
            ("Aplicativos", ColorTokens.warningOrange, remaining * 0.45),
            ("iOS", Color(.systemGray3), remaining * 0.35),
            ("Dados do Sistema", Color(.systemGray5), remaining * 0.20),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)

            // Title
            Text("Otimizar o\nArmazenamento do iPhone")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(ColorTokens.primaryText)

            Spacer().frame(height: 14)

            // Subtitle
            Text("Liberte até 80% do seu armazenamento e tenha mais espaço.")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Icons row
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
                }

                VStack(spacing: 10) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "3F9BFF"))
                        .frame(width: AppConstants.UI.iconSize, height: AppConstants.UI.iconSize)
                    Text("iCloud")
                        .font(.system(size: 15, weight: .medium))
                }
            }

            Spacer().frame(height: 24)

            // iPhone storage text
            HStack(spacing: 12) {
                Text("iPhone")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(viewModel.storageInfo.usedGB) GB de \(viewModel.storageInfo.totalGB) GB usados")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
            }

            Spacer().frame(height: 14)

            // Segmented storage bar
            segmentedStorageBar()
                .padding(.horizontal, 40)

            Spacer().frame(height: 14)

            // Legend
            legendView()

            Spacer()

            // Disclaimer
            Text("*Com base nos dados internos do StorageCleaner")
                .font(.system(size: 11))
                .foregroundColor(ColorTokens.tertiaryText)

            Spacer().frame(height: 18)

            // Button
            Button("Próximo") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.horizontalPadding)

            Spacer().frame(height: 14)

            // Footer links
            HStack(spacing: 6) {
                Button(action: { viewModel.openPrivacyPolicy() }) {
                    Text("Política de Privacidade")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.tertiaryText)
                }
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTokens.tertiaryText)
                Button(action: { viewModel.openTermsOfUse() }) {
                    Text("Termos de Uso")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.tertiaryText)
                }
            }

            Spacer().frame(height: 24)
        }
    }

    // MARK: - Segmented Bar

    @ViewBuilder
    private func segmentedStorageBar() -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(storageCategories.enumerated()), id: \.offset) { _, cat in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cat.color)
                        .frame(width: max(4, geo.size.width * cat.ratio))
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
    }

    // MARK: - Legend

    @ViewBuilder
    private func legendView() -> some View {
        HStack(spacing: 16) {
            ForEach(Array(storageCategories.enumerated()), id: \.offset) { _, cat in
                HStack(spacing: 6) {
                    Circle()
                        .fill(cat.color)
                        .frame(width: 10, height: 10)
                    Text(cat.name)
                        .font(.system(size: 12))
                        .foregroundColor(ColorTokens.secondaryText)
                }
            }
        }
    }
}
