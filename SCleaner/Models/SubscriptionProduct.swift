import Foundation
import RevenueCat

/// Represents the app's subscription tiers
enum SubscriptionTier: String, Comparable {
    case none
    case freeTrial   // com.vortexcleaner.weekly.trial ($6.99/sem, intro 3 days free)
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
        case .week: unitName = NSLocalizedString("subscription.week", comment: "")
        case .month: unitName = NSLocalizedString("subscription.month", comment: "")
        case .year: unitName = NSLocalizedString("subscription.year", comment: "")
        case .day: unitName = NSLocalizedString("subscription.day", comment: "")
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
        case .day: return String(format: NSLocalizedString("subscription.freeTrialDays", comment: ""), period.value)
        case .week: return String(format: NSLocalizedString("subscription.freeTrialWeeks", comment: ""), period.value)
        case .month: return String(format: NSLocalizedString("subscription.freeTrialMonths", comment: ""), period.value)
        case .year: return String(format: NSLocalizedString("subscription.freeTrialYears", comment: ""), period.value)
        @unknown default: return nil
        }
    }

    /// Introductory offer price description (e.g., "US$ 0,99 por 7 dias")
    var introOfferPrice: String? {
        guard let offer = storeProduct?.introductoryDiscount else { return nil }
        let priceStr = offer.localizedPriceString

        let period = offer.subscriptionPeriod
        switch period.unit {
        case .day: return String(format: NSLocalizedString("subscription.introOfferDays", comment: ""), priceStr, period.value)
        case .week: return String(format: NSLocalizedString("subscription.introOfferWeeks", comment: ""), priceStr, period.value)
        case .month: return String(format: NSLocalizedString("subscription.introOfferMonths", comment: ""), priceStr, period.value)
        case .year: return String(format: NSLocalizedString("subscription.introOfferYears", comment: ""), priceStr, period.value)
        @unknown default: return priceStr
        }
    }
}
