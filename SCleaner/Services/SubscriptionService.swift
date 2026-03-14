import StoreKit
import Combine

/// Manages in-app subscriptions using StoreKit 2.
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

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await checkCurrentEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: AppConstants.Subscription.allProductIds)

            products = storeProducts.compactMap { product in
                guard let tier = AppConstants.Subscription.tier(for: product.id) else { return nil }
                return SubscriptionProduct(id: product.id, product: product, tier: tier)
            }
            .sorted { $0.tier < $1.tier }

        } catch {
            errorMessage = "Não foi possível carregar os planos. Verifique sua conexão."
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ subscriptionProduct: SubscriptionProduct) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await subscriptionProduct.product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerification(verification)
                await transaction.finish()
                await checkCurrentEntitlements()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                errorMessage = "Compra pendente de aprovação."
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
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
            try await AppStore.sync()
            await checkCurrentEntitlements()
            isLoading = false

            if isPremium {
                return true
            } else {
                errorMessage = "Nenhuma assinatura ativa encontrada."
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
        var highestTier: SubscriptionTier = .none

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerification(result) else { continue }

            if let tier = AppConstants.Subscription.tier(for: transaction.productID),
               tier > highestTier {
                highestTier = tier
            }
        }

        currentTier = highestTier
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                if let transaction = try? self.checkVerification(result) {
                    await transaction.finish()
                    await self.checkCurrentEntitlements()
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
