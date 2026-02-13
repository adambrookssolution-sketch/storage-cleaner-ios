import SwiftUI

/// Full settings screen with grouped list sections matching reference app design
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Premium banner
                premiumBanner

                // Support section
                Section {
                    settingsRow(icon: "questionmark.circle.fill", color: .blue, title: "Perguntas Frequentes") {
                        // M2+: Navigate to FAQ
                    }
                    settingsRow(icon: "envelope.fill", color: .blue, title: "Fale Conosco") {
                        viewModel.contactSupport()
                    }
                    settingsRow(icon: "arrow.clockwise", color: .green, title: "Restaurar Compras") {
                        viewModel.restorePurchases()
                    }
                    settingsRow(icon: "info.circle.fill", color: .gray, title: "Sobre") {
                        // M2+: Navigate to About
                    }
                    settingsRow(icon: "hand.raised.fill", color: .blue, title: "Política de Privacidade") {
                        viewModel.openPrivacyPolicy()
                    }
                    settingsRow(icon: "doc.text.fill", color: .gray, title: "Termos de Uso") {
                        viewModel.openTermsOfUse()
                    }
                } header: {
                    Text("SUPORTE")
                }

                // Social section
                Section {
                    settingsRow(icon: "star.fill", color: .yellow, title: "Avalie o App") {
                        viewModel.rateApp()
                    }
                    settingsRow(icon: "square.and.arrow.up.fill", color: .blue, title: "Compartilhar") {
                        viewModel.shareApp()
                    }
                    settingsRow(icon: "camera.fill", color: .purple, title: "Instagram") {
                        viewModel.openInstagram()
                    }
                } header: {
                    Text("MANTENHA CONTATO")
                }

                // Footer
                Section {
                    EmptyView()
                } footer: {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(ColorTokens.primaryBlue.opacity(0.4))

                        Text("StorageCleaner")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ColorTokens.tertiaryText)

                        Text("Versão \(viewModel.appVersion)")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        Section {
            Button(action: {
                // M4: Navigate to paywall
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Desbloquear acesso ilimitado")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ColorTokens.primaryText)
                        Text("Remova todos os limites")
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTokens.tertiaryText)
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Settings Row

    private func settingsRow(
        icon: String,
        color: Color,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(color)
                    )

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(ColorTokens.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
        }
    }
}
