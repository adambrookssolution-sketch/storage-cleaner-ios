import SwiftUI

/// Onboarding Step 3: Animated tutorial showing duplicate detection concept
/// Matches Screenshots 4-6 from reference app
struct DuplicatesTutorialStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    // Colors for tutorial photo placeholders
    private let photoColors: [(Color, Color)] = [
        (Color(hex: "87CEEB"), Color(hex: "87CEEB").opacity(0.8)),  // Sky blue pair
        (Color(hex: "FFB347"), Color(hex: "FFB347").opacity(0.8)),  // Orange pair
        (Color(hex: "98D8C8"), Color(hex: "98D8C8").opacity(0.8)),  // Mint pair
    ]

    private let photoIcons: [String] = [
        "mountain.2.fill",
        "person.crop.circle.fill",
        "cat.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)

            // Title
            Text("Excluir Fotos\nDuplicadas")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(ColorTokens.primaryText)

            Spacer().frame(height: 14)

            // Subtitle
            Text("Elimine fotos duplicadas instantaneamente e recupere seu armazenamento!")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 36)

            // Photo pairs / animation area
            VStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { index in
                    tutorialRow(index: index)
                }
            }
            .padding(.horizontal, 50)

            Spacer()

            // Button
            Button("Próximo") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.horizontalPadding)

            Spacer().frame(height: 14)

            // Footer links
            footerLinks

            Spacer().frame(height: 24)
        }
        .onAppear {
            viewModel.startDuplicateTutorial()
        }
    }

    // MARK: - Tutorial Row

    @ViewBuilder
    private func tutorialRow(index: Int) -> some View {
        let phase = viewModel.tutorialPhase
        let colors = photoColors[index]

        HStack(spacing: 14) {
            // Keeper photo (always visible)
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [colors.0, colors.0.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: photoIcons[index])
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.9))
                    )

                // Gray circle checkbox (keeper)
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.9)))
                    .padding(8)
            }

            // Duplicate photo (slides away in phase 3)
            if phase != .animateRemoval {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [colors.1, colors.1.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: photoIcons[index])
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.7))
                        )

                    // Checkmark circle
                    if phase == .animateSelection {
                        Circle()
                            .fill(ColorTokens.destructiveRed)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 2)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                            .padding(8)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
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
    }
}
