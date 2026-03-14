import StoreKit

/// Represents the app's subscription tiers
enum SubscriptionTier: String, Comparable {
    case none
    case weekly
    case annual

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.none, .weekly, .annual]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// Wraps a StoreKit 2 Product with subscription-specific display helpers
struct SubscriptionProduct: Identifiable {
    let id: String
    let product: Product
    let tier: SubscriptionTier

    var displayName: String { product.displayName }
    var description: String { product.description }
    var displayPrice: String { product.displayPrice }

    /// Formatted price per period (e.g. "R$ 9,90 / semana")
    var pricePerPeriod: String {
        guard let subscription = product.subscription else { return displayPrice }
        let period = subscription.subscriptionPeriod
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

    /// Weekly equivalent price for annual plan display
    var weeklyEquivalentPrice: String? {
        guard tier == .annual,
              let subscription = product.subscription,
              subscription.subscriptionPeriod.unit == .year else { return nil }
        let weeklyPrice = product.price / 52
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        return formatter.string(from: weeklyPrice as NSDecimalNumber)
    }

    /// Whether this product offers a free trial
    var hasFreeTrial: Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Free trial period description
    var freeTrialDescription: String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return "\(period.value) dia\(period.value > 1 ? "s" : "") grátis"
        case .week: return "\(period.value) semana\(period.value > 1 ? "s" : "") grátis"
        case .month: return "\(period.value) mês\(period.value > 1 ? "es" : "") grátis"
        case .year: return "\(period.value) ano\(period.value > 1 ? "s" : "") grátis"
        @unknown default: return nil
        }
    }
}
