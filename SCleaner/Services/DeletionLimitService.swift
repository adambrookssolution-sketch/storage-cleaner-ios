import Foundation

/// Tracks daily deletion count for free-tier enforcement.
/// Resets count at midnight each day. Premium users bypass all limits.
/// Controlled by AppConstants.Subscription.paywallEnabled flag.
@MainActor
final class DeletionLimitService: ObservableObject {

    static let shared = DeletionLimitService()

    private let dailyLimitKey = "SCleaner_DailyDeleteCount"
    private let dailyDateKey = "SCleaner_DailyDeleteDate"

    @Published private(set) var deletionsToday: Int = 0

    var dailyLimit: Int { AppConstants.Subscription.freeDeleteLimit }

    var remainingDeletions: Int {
        max(0, dailyLimit - deletionsToday)
    }

    var isLimitReached: Bool {
        guard AppConstants.Subscription.paywallEnabled else { return false }
        return !SubscriptionService.shared.isPremium && deletionsToday >= dailyLimit
    }

    private init() {
        loadTodayCount()
    }

    func canDelete(count: Int) -> Bool {
        guard AppConstants.Subscription.paywallEnabled else { return true }
        if SubscriptionService.shared.isPremium { return true }
        return (deletionsToday + count) <= dailyLimit
    }

    func recordDeletions(count: Int) {
        resetIfNewDay()
        deletionsToday += count
        save()
    }

    func allowedCount(requested: Int) -> Int {
        guard AppConstants.Subscription.paywallEnabled else { return requested }
        if SubscriptionService.shared.isPremium { return requested }
        return min(requested, remainingDeletions)
    }

    // MARK: - Persistence

    private func loadTodayCount() {
        let savedDate = UserDefaults.standard.string(forKey: dailyDateKey) ?? ""
        let todayStr = Self.todayString()

        if savedDate == todayStr {
            deletionsToday = UserDefaults.standard.integer(forKey: dailyLimitKey)
        } else {
            deletionsToday = 0
            save()
        }
    }

    private func resetIfNewDay() {
        let savedDate = UserDefaults.standard.string(forKey: dailyDateKey) ?? ""
        let todayStr = Self.todayString()
        if savedDate != todayStr {
            deletionsToday = 0
        }
    }

    private func save() {
        UserDefaults.standard.set(deletionsToday, forKey: dailyLimitKey)
        UserDefaults.standard.set(Self.todayString(), forKey: dailyDateKey)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
