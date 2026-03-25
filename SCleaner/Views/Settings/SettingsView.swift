import SwiftUI

/// Full settings screen with grouped list sections matching reference app design
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var showFAQ = false
    @State private var showAbout = false

    var body: some View {
        NavigationView {
            List {
                // Premium banner — hidden when paywall disabled OR user is already premium
                if AppConstants.Subscription.paywallEnabled && !SubscriptionService.shared.isPremium {
                    premiumBanner
                }

                // Support section
                Section {
                    settingsRow(icon: "questionmark.circle.fill", color: .blue, title: NSLocalizedString("settings.faq", comment: "")) {
                        showFAQ = true
                    }
                    settingsRow(icon: "envelope.fill", color: .blue, title: NSLocalizedString("settings.contactSupport", comment: "")) {
                        viewModel.contactSupport()
                    }
                    if AppConstants.Subscription.paywallEnabled {
                        settingsRow(icon: "arrow.clockwise", color: .green, title: NSLocalizedString("settings.restorePurchases", comment: "")) {
                            viewModel.restorePurchases()
                        }
                    }
                    settingsRow(icon: "info.circle.fill", color: .gray, title: NSLocalizedString("settings.about", comment: "")) {
                        showAbout = true
                    }
                    settingsRow(icon: "hand.raised.fill", color: .blue, title: NSLocalizedString("settings.privacyPolicy", comment: "")) {
                        viewModel.openPrivacyPolicy()
                    }
                    settingsRow(icon: "doc.text.fill", color: .gray, title: NSLocalizedString("settings.termsOfUse", comment: "")) {
                        viewModel.openTermsOfUse()
                    }
                } header: {
                    Text(NSLocalizedString("settings.supportSection", comment: ""))
                }

                // Social section
                Section {
                    settingsRow(icon: "star.fill", color: .yellow, title: NSLocalizedString("settings.rateApp", comment: "")) {
                        viewModel.rateApp()
                    }
                    settingsRow(icon: "square.and.arrow.up.fill", color: .blue, title: NSLocalizedString("settings.shareApp", comment: "")) {
                        viewModel.shareApp()
                    }
                    settingsRow(icon: "camera.fill", color: .purple, title: NSLocalizedString("settings.instagram", comment: "")) {
                        viewModel.openInstagram()
                    }
                } header: {
                    Text(NSLocalizedString("settings.socialSection", comment: ""))
                }

                // Footer
                Section {
                    EmptyView()
                } footer: {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(ColorTokens.primaryBlue.opacity(0.4))

                        Text(AppConstants.AppInfo.appName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ColorTokens.tertiaryText)

                        Text(String(format: NSLocalizedString("settings.versionFormat", comment: ""), viewModel.appVersion))
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
        .alert(NSLocalizedString("settings.restorePurchases", comment: ""), isPresented: $viewModel.showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.restoreAlertMessage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        Section {
            Button(action: {
                showPaywall = true
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
                        Text(NSLocalizedString("settings.unlockPremium", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ColorTokens.primaryText)
                        Text(NSLocalizedString("settings.removeLimits", comment: ""))
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
