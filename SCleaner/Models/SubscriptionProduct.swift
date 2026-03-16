import RevenueCat

/// Represents the app's subscription tiers
enum SubscriptionTier: String, Comparable {
    case none
    case freeTrial   // com.vortexcleaner.free.3days ($6.99/sem, intro 3 days free)
    case weekly      // com.vortexcleaner.weekly ($7.99/sem, intro $0.99)
    case monthly     // com.vortexcleaner.monthly ($28/mês)

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.none, .freeTrial, .weekly, .monthly]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// Wraps a RevenueCat Package with subscription-specific display helpers
struct SubscriptionProduct: Identifiable {
    let id: String
    let rcPackage: Package?
    let tier: SubscriptionTier

    var storeProduct: RevenueCat.StoreProduct? { rcPackage?.storeProduct }

    var displayName: String {
        storeProduct?.localizedTitle ?? tier.rawValue
    }

    var description: String {
        storeProduct?.localizedDescription ?? ""
    }

    var displayPrice: String {
        storeProduct?.localizedPriceString ?? ""
    }

    /// Formatted price per period (e.g. "US$ 7,99 / semana")
    var pricePerPeriod: String {
        guard let product = storeProduct,
              let period = product.subscriptionPeriod else { return displayPrice }
        let unitName: String
        switch period.unit {
        case .week: unitName = "semana"
        case .month: unitName = "mês"
        case .year: unitName = "ano"
        case .day: unitName = "dia"
        @unknown default: unitName = ""
        }
        return "\(displayPrice) / \(unitName)"
    }

    /// Whether this product offers a free trial
    var hasFreeTrial: Bool {
        storeProduct?.introductoryDiscount?.paymentMode == .freeTrial
    }

    /// Free trial period description
    var freeTrialDescription: String? {
        guard let offer = storeProduct?.introductoryDiscount,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.subscriptionPeriod
        switch period.unit {
        case .day: return "\(period.value) dia\(period.value > 1 ? "s" : "") grátis"
        case .week: return "\(period.value) semana\(period.value > 1 ? "s" : "") grátis"
        case .month: return "\(period.value) mês\(period.value > 1 ? "es" : "") grátis"
        case .year: return "\(period.value) ano\(period.value > 1 ? "s" : "") grátis"
        @unknown default: return nil
        }
    }

    /// Introductory offer price description (e.g., "US$ 0,99 por 7 dias")
    var introOfferPrice: String? {
        guard let offer = storeProduct?.introductoryDiscount else { return nil }
        let priceStr = offer.localizedPriceString

        let period = offer.subscriptionPeriod
        switch period.unit {
        case .day: return "\(priceStr) por \(period.value) dia\(period.value > 1 ? "s" : "")"
        case .week: return "\(priceStr) por \(period.value) semana\(period.value > 1 ? "s" : "")"
        case .month: return "\(priceStr) por \(period.value) mês\(period.value > 1 ? "es" : "")"
        case .year: return "\(priceStr) por \(period.value) ano\(period.value > 1 ? "s" : "")"
        @unknown default: return priceStr
        }
    }
}
