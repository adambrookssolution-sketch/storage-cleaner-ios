import SwiftUI

/// 2-page paywall flow:
/// Page 1: Main paywall with weekly (intro offer) + monthly (anchor) plans
/// Page 2: Retention screen with free trial offer (appears when user taps "Agora Não")
struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: SubscriptionProduct?
    @State private var showRetention = false
    @State private var showSuccess = false
    @State private var isPurchasing = false

    /// Optional scan result counters to show during-scan paywall
    var scanPhotos: Int = 0
    var scanVideos: Int = 0
    var scanScreenshots: Int = 0

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "0EA5E9"), Color(hex: "0284C7"), Color(hex: "0369A1")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showSuccess {
                successView
            } else if showRetention {
                retentionPage
            } else {
                mainPaywallPage
            }
        }
        .task {
            await subscriptionService.loadProducts()
            // Default to weekly (intro offer)
            selectedProduct = subscriptionService.products.first(where: { $0.tier == .weekly })
                ?? subscriptionService.products.first
        }
    }

    // MARK: - Page 1: Main Paywall

    private var mainPaywallPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Logo + badge
                    VStack(spacing: 12) {
                        // App logo
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            .padding(.top, 40)

                        Text("ACESSO PREMIUM")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.25)))
                    }

                    // Title
                    Text("Acesso Completo")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.white)

                    // Benefits list — show live scan results if available
                    VStack(alignment: .leading, spacing: 12) {
                        if hasScanResults {
                            if scanPhotos > 0 {
                                benefitRow("\(scanPhotos) fotos duplicadas encontradas")
                            }
                            if scanVideos > 0 {
                                benefitRow("\(scanVideos) vídeos para revisar")
                            }
                            if scanScreenshots > 0 {
                                benefitRow("\(scanScreenshots) capturas de tela")
                            }
                            benefitRow("Exclusões ilimitadas")
                            benefitRow("Todas as futuras atualizações")
                        } else {
                            benefitRow("Exclusões ilimitadas de fotos e vídeos")
                            benefitRow("Detecção avançada de duplicatas")
                            benefitRow("Limpeza completa de screenshots")
                            benefitRow("Scanner de downloads pesados")
                            benefitRow("Todas as futuras atualizações")
                        }
                    }
                    .padding(.horizontal, 30)

                    // Social proof
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Milhares de pessoas já assinaram!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.15))
                    )

                    // Plan cards
                    VStack(spacing: 12) {
                        // Weekly plan (intro offer — BEST VALUE)
                        if let weekly = subscriptionService.products.first(where: { $0.tier == .weekly }) {
                            planCardWeekly(weekly)
                        }

                        // Monthly plan (anchor — makes weekly look cheap)
                        if let monthly = subscriptionService.products.first(where: { $0.tier == .monthly }) {
                            planCardMonthly(monthly)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Legal text
                    Text("Assinatura renovável automaticamente. Cancele quando quiser nas Configurações.\nPagamento cobrado na conta do iTunes.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 140)
            }

            // Bottom: CTA + links
            VStack(spacing: 10) {
                // CTA Button
                Button(action: purchaseSelected) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Color(hex: "0284C7"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text(ctaText)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Color(hex: "0284C7"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .disabled(isPurchasing)
                .padding(.horizontal, 20)

                // Legal links
                Text("Ao assinar, você concorda com nossos ")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                +
                Text("Termos de Uso")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .underline()
                +
                Text(" e ")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                +
                Text("Política de Privacidade")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .underline()

                // Bottom row: Restore + Agora Não (disguised close)
                HStack(spacing: 20) {
                    Button("Restaurar Compras") {
                        Task {
                            let restored = await subscriptionService.restorePurchases()
                            if restored { showSuccess = true }
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                    Text("·")
                        .foregroundColor(.white.opacity(0.3))

                    Button("Agora Não") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showRetention = true
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0369A1").opacity(0), Color(hex: "0369A1")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Page 2: Retention (Free Trial)

    private var retentionPage: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.15)))
                }
                .padding(.trailing, 20)
                .padding(.top, 16)
            }

            Spacer()

            VStack(spacing: 20) {
                Text("OFERTA ÚNICA")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(2)

                // Big free trial card
                VStack(spacing: 8) {
                    Text("TESTE\nGRÁTIS")
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(Color(hex: "0284C7"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                )
                .padding(.horizontal, 40)

                Text("Esta oferta não estará aqui\nquando você fechar!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
                    .multilineTextAlignment(.center)

                // Trial details — uses the free.3days product
                if let trialProduct = subscriptionService.products.first(where: { $0.tier == .freeTrial }) {
                    Text("Teste \(AppConstants.Subscription.trialDays) dias depois \(trialProduct.pricePerPeriod). Acesso completo a todos os recursos! Sem custo extra, sem compromisso. Cancele quando quiser.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }

            Spacer()

            // CTA
            VStack(spacing: 16) {
                Button(action: {
                    // Retention page uses the free.3days product (3 days free → $6.99/week)
                    if let trialProduct = subscriptionService.products.first(where: { $0.tier == .freeTrial }) {
                        selectedProduct = trialProduct
                        purchaseSelected()
                    }
                }) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Color(hex: "0284C7"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        HStack {
                            Text("Continuar")
                                .font(.system(size: 18, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "0284C7"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .disabled(isPurchasing)
                .padding(.horizontal, 30)

                // Legal links
                HStack(spacing: 12) {
                    linkButton("Termos de Uso", url: AppConstants.URLs.termsOfUse)
                    Text("·").foregroundColor(.white.opacity(0.3))
                    linkButton("Política de Privacidade", url: AppConstants.URLs.privacyPolicy)
                    Text("·").foregroundColor(.white.opacity(0.3))
                    Button("Restaurar Compras") {
                        Task {
                            let restored = await subscriptionService.restorePurchases()
                            if restored { showSuccess = true }
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 30)
        }
    }

    private var hasScanResults: Bool {
        scanPhotos > 0 || scanVideos > 0 || scanScreenshots > 0
    }

    // MARK: - Helpers

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func planCardWeekly(_ product: SubscriptionProduct) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button(action: { selectedProduct = product }) {
            VStack(spacing: 0) {
                // "MELHOR VALOR" badge
                Text("MELHOR VALOR")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(hex: "22C55E"))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let introPrice = product.introOfferPrice {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Oferta Especial")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Text(introPrice)
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.white)
                        } else {
                            Text(product.displayPrice)
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.white)
                        }

                        Text("depois \(product.pricePerPeriod)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(.white.opacity(0.15))
                            )
                    }
                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isSelected ? 0.25 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .white : .white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func planCardMonthly(_ product: SubscriptionProduct) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button(action: { selectedProduct = product }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .stroke(isSelected ? .white : .white.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(isSelected ? .white : .clear)
                                    .frame(width: 12, height: 12)
                            )

                        Text("Mensal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text(product.displayPrice + "/mensal")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)

                    Text("Cobrado mensalmente")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isSelected ? 0.2 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .white : .white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private var ctaText: String {
        if let product = selectedProduct, product.hasFreeTrial {
            return "INICIAR \(AppConstants.Subscription.trialDays) DIAS PREMIUM"
        }
        return "INICIAR 7 DIAS PREMIUM"
    }

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            let success = await subscriptionService.purchase(product)
            isPurchasing = false
            if success {
                withAnimation { showSuccess = true }
            }
        }
    }

    private func linkButton(_ title: String, url: String) -> some View {
        Button(title) {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
            }

            Text("Assinatura ativada!")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Agora você tem acesso ilimitado\na todos os recursos.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()

            Button("Continuar") {
                dismiss()
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Color(hex: "0284C7"))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}
