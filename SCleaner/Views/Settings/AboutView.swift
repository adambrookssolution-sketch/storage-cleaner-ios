import SwiftUI

/// About screen showing app information
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // App icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.primaryBlue, Color(hex: "5856D6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("StorageCleaner")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTokens.primaryText)

                    Text("Versao \(AppConstants.AppInfo.version) (\(AppConstants.AppInfo.buildNumber))")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTokens.secondaryText)
                }

                Text("Organize suas fotos, libere espaco e mantenha seu iPhone sempre rapido e organizado.")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 16) {
                    linkButton(title: "Politica de Privacidade", url: AppConstants.URLs.privacyPolicy)
                    linkButton(title: "Termos de Uso", url: AppConstants.URLs.termsOfUse)
                    linkButton(title: "Suporte", url: "mailto:\(AppConstants.URLs.supportEmail)")
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(ColorTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("Sobre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
    }

    private func linkButton(title: String, url: String) -> some View {
        Button(action: {
            guard let linkURL = URL(string: url) else { return }
            UIApplication.shared.open(linkURL)
        }) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.primaryBlue)
        }
    }
}
