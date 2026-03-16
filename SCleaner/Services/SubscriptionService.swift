import RevenueCat
import StoreKit
import Combine

/// Manages subscriptions via RevenueCat.
/// Single source of truth for subscription state across the app.
@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Published State

    @Published private(set) var products: [SubscriptionProduct] = []
    @Published private(set) var currentTier: SubscriptionTier = .none
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isPremium: Bool { currentTier != .none }

    // MARK: - Init

    private init() {
        Task { await checkCurrentEntitlements() }
    }

    /// Call once at app launch (in App init or AppDelegate)
    static func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: AppConstants.RevenueCat.apiKey)
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let offerings = try await Purchases.shared.offerings()

            guard let current = offerings.current else {
                errorMessage = "Nenhum plano disponível no momento."
                isLoading = false
                return
            }

            products = current.availablePackages.compactMap { package in
                let productId = package.storeProduct.productIdentifier
                guard let tier = AppConstants.Subscription.tier(for: productId) else { return nil }

                // Wrap RevenueCat StoreProduct into our SubscriptionProduct
                return SubscriptionProduct(
                    id: productId,
                    rcPackage: package,
                    tier: tier
                )
            }
            .sorted { $0.tier < $1.tier }

        } catch {
            errorMessage = "Não foi possível carregar os planos. Verifique sua conexão."
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ subscriptionProduct: SubscriptionProduct) async -> Bool {
        guard let package = subscriptionProduct.rcPackage else { return false }
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if result.customerInfo.entitlements[AppConstants.RevenueCat.entitlementId]?.isActive == true {
                await checkCurrentEntitlements()
                isLoading = false
                return true
            }

            isLoading = false
            return false

        } catch let error as RevenueCat.ErrorCode {
            if error == .purchaseCancelledError {
                // User cancelled — not an error
            } else {
                errorMessage = "Erro ao processar a compra. Tente novamente."
            }
            isLoading = false
            return false
        } catch {
            errorMessage = "Erro ao processar a compra. Tente novamente."
            isLoading = false
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await Purchases.shared.restorePurchases()
            let isActive = info.entitlements[AppConstants.RevenueCat.entitlementId]?.isActive == true

            if isActive {
                await checkCurrentEntitlements()
                isLoading = false
                return true
            } else {
                errorMessage = "Nenhuma assinatura ativa encontrada."
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Erro ao restaurar compras. Tente novamente."
            isLoading = false
            return false
        }
    }

    // MARK: - Check Entitlements

    func checkCurrentEntitlements() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            let isActive = info.entitlements[AppConstants.RevenueCat.entitlementId]?.isActive == true

            if isActive {
                // Determine which product is active
                if let activeProductId = info.entitlements[AppConstants.RevenueCat.entitlementId]?.productIdentifier,
                   let tier = AppConstants.Subscription.tier(for: activeProductId) {
                    currentTier = tier
                } else {
                    currentTier = .weekly // Default to weekly if active but unknown product
                }
            } else {
                currentTier = .none
            }
        } catch {
            // Silently fail — keep current state
        }
    }
}
