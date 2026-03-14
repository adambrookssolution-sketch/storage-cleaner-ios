import SwiftUI

/// Full-screen paywall for subscription plan selection and purchase
struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: SubscriptionProduct?
    @State private var showSuccess = false
    @State private var isPurchasing = false

    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.screenBackground.ignoresSafeArea()

                if subscriptionService.isLoading && subscriptionService.products.isEmpty {
                    loadingView
                } else if showSuccess {
                    successView
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ColorTokens.secondaryText)
                    }
                }
            }
        }
        .task {
            await subscriptionService.loadProducts()
            if selectedProduct == nil {
                selectedProduct = subscriptionService.products.first(where: { $0.tier == .annual })
                    ?? subscriptionService.products.first
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    plansSection

                    if let error = subscriptionService.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.destructiveRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppConstants.UI.horizontalPadding)
                    }
                }
                .padding(.bottom, 120)
            }

            purchaseButton
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)

            Text("Desbloquear Acesso\nIlimitado")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)
                .multilineTextAlignment(.center)

            Text("Aproveite todos os recursos sem limites")
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.secondaryText)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 14) {
            featureRow(icon: "infinity", text: "Exclusões ilimitadas de fotos")
            featureRow(icon: "bolt.fill", text: "Escaneamento avançado completo")
            featureRow(icon: "arrow.down.circle.fill", text: "Limpeza de downloads sem limites")
            featureRow(icon: "trash.fill", text: "Lixeira do app com restauração")
            featureRow(icon: "sparkles", text: "Todas as futuras atualizações")
        }
        .padding(.horizontal, AppConstants.UI.horizontalPadding)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "FFD700"))
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.primaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(ColorTokens.successGreen)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionService.products, id: \.id) { product in
                planCard(product)
            }
        }
        .padding(.horizontal, AppConstants.UI.horizontalPadding)
    }

    private func planCard(_ product: SubscriptionProduct) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isAnnual = product.tier == .annual

        return Button(action: { selectedProduct = product }) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "FFD700") : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color(hex: "FFD700"))
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ColorTokens.primaryText)

                        if isAnnual {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "FF8C00"))
                                )
                        }
                    }

                    if let trial = product.freeTrialDescription {
                        Text(trial)
                            .font(.system(size: 13))
                            .foregroundColor(ColorTokens.successGreen)
                    }

                    if let weeklyPrice = product.weeklyEquivalentPrice {
                        Text("\(weeklyPrice) / semana")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.secondaryText)
                    }
                }

                Spacer()

                Text(product.pricePerPeriod)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorTokens.primaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "FFD700") : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                guard let product = selectedProduct else { return }
                isPurchasing = true
                Task {
                    let success = await subscriptionService.purchase(product)
                    isPurchasing = false
                    if success {
                        showSuccess = true
                    }
                }
            }) {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppConstants.UI.buttonHeight)
                } else {
                    Text(buttonText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppConstants.UI.buttonHeight)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.buttonCornerRadius))
            .disabled(selectedProduct == nil || isPurchasing)

            HStack(spacing: 16) {
                Button("Restaurar Compras") {
                    Task {
                        let restored = await subscriptionService.restorePurchases()
                        if restored { showSuccess = true }
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTokens.secondaryText)

                Text("•")
                    .foregroundColor(ColorTokens.tertiaryText)

                Button("Termos de Uso") {
                    if let url = URL(string: AppConstants.URLs.termsOfUse) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTokens.secondaryText)

                Text("•")
                    .foregroundColor(ColorTokens.tertiaryText)

                Button("Privacidade") {
                    if let url = URL(string: AppConstants.URLs.privacyPolicy) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTokens.secondaryText)
            }
        }
        .padding(.horizontal, AppConstants.UI.horizontalPadding)
        .padding(.bottom, 30)
        .background(
            ColorTokens.screenBackground
                .shadow(color: .black.opacity(0.08), radius: 10, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var buttonText: String {
        guard let product = selectedProduct else { return "Selecione um plano" }
        if product.hasFreeTrial {
            return "Iniciar teste gratuito"
        }
        return "Assinar agora"
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Carregando planos...")
                .font(.system(size: 15))
                .foregroundColor(ColorTokens.secondaryText)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.successGreen.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ColorTokens.successGreen)
            }

            Text("Assinatura ativada!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTokens.primaryText)

            Text("Agora voce tem acesso ilimitado a todos os recursos.")
                .font(.system(size: 16))
                .foregroundColor(ColorTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button("Continuar") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppConstants.UI.horizontalPadding)
            .padding(.bottom, 40)
        }
    }
}
