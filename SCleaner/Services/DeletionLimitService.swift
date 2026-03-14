import Foundation

/// Tracks daily deletion count for free-tier enforcement.
/// Resets count at midnight each day. Premium users bypass all limits.
@MainActor
final class DeletionLimitService: ObservableObject {

    static let shared = DeletionLimitService()

    private let dailyLimitKey = "SCleaner_DailyDeleteCount"
    private let dailyDateKey = "SCleaner_DailyDeleteDate"

    @Published private(set) var deletionsToday: Int = 0

    /// Maximum free deletions per day
    var dailyLimit: Int { AppConstants.Subscription.freeDeleteLimit }

    /// Remaining free deletions available today
    var remainingDeletions: Int {
        max(0, dailyLimit - deletionsToday)
    }

    /// Whether the daily limit has been reached for free users
    var isLimitReached: Bool {
        !SubscriptionService.shared.isPremium && deletionsToday >= dailyLimit
    }

    private init() {
        loadTodayCount()
    }

    /// Check if deletion of `count` items is allowed.
    /// Premium users always return true. Free users are limited to `freeDeleteLimit` per day.
    func canDelete(count: Int) -> Bool {
        if SubscriptionService.shared.isPremium { return true }
        return (deletionsToday + count) <= dailyLimit
    }

    /// Record that `count` items were successfully deleted.
    func recordDeletions(count: Int) {
        resetIfNewDay()
        deletionsToday += count
        save()
    }

    /// Number of items allowed to delete right now (for partial deletion)
    func allowedCount(requested: Int) -> Int {
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
            // New day — reset
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
