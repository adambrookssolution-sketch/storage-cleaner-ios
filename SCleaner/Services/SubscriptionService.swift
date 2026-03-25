import RevenueCat
import StoreKit
import Combine

/// Manages subscriptions via RevenueCat.
/// Implements PurchasesDelegate for real-time entitlement updates (trial expiry, cancellation, billing failure).
@MainActor
final class SubscriptionService: NSObject, ObservableObject, PurchasesDelegate {

    static let shared = SubscriptionService()

    // MARK: - Published State

    @Published private(set) var products: [SubscriptionProduct] = []
    @Published private(set) var currentTier: SubscriptionTier = .none
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isPremium: Bool { currentTier != .none }

    // MARK: - Init

    private override init() {
        super.init()
        Task { await checkCurrentEntitlements() }
    }

    /// Call once at app launch (in App init)
    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: AppConstants.RevenueCat.apiKey)
        Purchases.shared.delegate = SubscriptionService.shared
    }

    // MARK: - PurchasesDelegate (real-time entitlement updates)

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateEntitlements(from: customerInfo)
        }
    }

    // MARK: - Foreground Revalidation

    /// Call when app returns to foreground (scenePhase == .active)
    func revalidateOnForeground() {
        Task { await checkCurrentEntitlements() }
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let offerings = try await Purchases.shared.offerings()

            guard let current = offerings.current else {
                errorMessage = NSLocalizedString("subscription.noPlansAvailable", comment: "")
                isLoading = false
                return
            }

            products = current.availablePackages.compactMap { package in
                let productId = package.storeProduct.productIdentifier
                guard let tier = AppConstants.Subscription.tier(for: productId) else { return nil }
                return SubscriptionProduct(id: productId, rcPackage: package, tier: tier)
            }
            .sorted { $0.tier < $1.tier }

        } catch {
            errorMessage = NSLocalizedString("subscription.errorLoadingPlans", comment: "")
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
                updateEntitlements(from: result.customerInfo)
                isLoading = false
                return true
            }

            isLoading = false
            return false

        } catch let error as RevenueCat.ErrorCode {
            if error != .purchaseCancelledError {
                errorMessage = NSLocalizedString("subscription.purchaseError", comment: "")
            }
            isLoading = false
            return false
        } catch {
            errorMessage = NSLocalizedString("subscription.purchaseError", comment: "")
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
                updateEntitlements(from: info)
                isLoading = false
                return true
            } else {
                errorMessage = NSLocalizedString("subscription.noActiveSubscription", comment: "")
                isLoading = false
                return false
            }
        } catch {
            errorMessage = NSLocalizedString("subscription.restoreError", comment: "")
            isLoading = false
            return false
        }
    }

    // MARK: - Check Entitlements

    func checkCurrentEntitlements() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateEntitlements(from: info)
        } catch {
            // Silently fail — keep current state
        }
    }

    /// Unified entitlement update — used by delegate, purchase, restore, and foreground check
    private func updateEntitlements(from info: CustomerInfo) {
        let isActive = info.entitlements[AppConstants.RevenueCat.entitlementId]?.isActive == true

        if isActive {
            if let activeProductId = info.entitlements[AppConstants.RevenueCat.entitlementId]?.productIdentifier,
               let tier = AppConstants.Subscription.tier(for: activeProductId) {
                currentTier = tier
            } else {
                currentTier = .weekly
            }
        } else {
            currentTier = .none
        }
    }
}
