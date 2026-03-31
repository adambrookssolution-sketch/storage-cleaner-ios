import StoreKit
import Foundation
import UIKit

/// Requests App Store reviews at appropriate moments, respecting Apple's rate limits.
/// Apple allows a maximum of 3 review prompts per year, per app version.
/// We trigger on: 1st and 2nd completed scan, 5th app launch, post-deletion success.
final class ReviewPromptService {

    static let shared = ReviewPromptService()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let scanCompletionCount = "reviewPrompt.scanCompletionCount"
        static let launchCount = "reviewPrompt.launchCount"
        static let lastPromptDate = "reviewPrompt.lastPromptDate"
        static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
        static let promptCountThisVersion = "reviewPrompt.promptCountThisVersion"
    }

    // MARK: - Constants

    private let minDaysBetweenPrompts = 30
    private let maxPromptsPerVersion = 3

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Init

    private init() {}

    // MARK: - Public Triggers

    /// Call each time the app finishes a scan. Prompts after the 1st and 2nd scan.
    func recordScanCompleted() {
        let count = UserDefaults.standard.integer(forKey: Keys.scanCompletionCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.scanCompletionCount)
        if count == 1 || count == 2 {
            requestReviewIfEligible()
        }
    }

    /// Call at app launch. Prompts on the 5th launch.
    func recordAppLaunch() {
        let count = UserDefaults.standard.integer(forKey: Keys.launchCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.launchCount)
        if count == 5 {
            requestReviewIfEligible()
        }
    }

    /// Call after a successful deletion of 5+ items.
    func recordDeletionSuccess(itemCount: Int) {
        guard itemCount >= 5 else { return }
        requestReviewIfEligible()
    }

    // MARK: - Private

    private func requestReviewIfEligible() {
        #if DEBUG
        // In debug builds, always show the prompt immediately for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
        #else
        guard canShowPrompt() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            SKStoreReviewController.requestReview(in: scene)
            self.recordPromptShown()
        }
        #endif
    }

    private func canShowPrompt() -> Bool {
        // Check version-level cap
        let promptedVersion = UserDefaults.standard.string(forKey: Keys.lastPromptedVersion) ?? ""
        let countThisVersion: Int
        if promptedVersion == currentVersion {
            countThisVersion = UserDefaults.standard.integer(forKey: Keys.promptCountThisVersion)
        } else {
            // New version — reset count
            UserDefaults.standard.set(0, forKey: Keys.promptCountThisVersion)
            countThisVersion = 0
        }
        guard countThisVersion < maxPromptsPerVersion else { return false }

        // Check cooldown between prompts
        if let lastDate = UserDefaults.standard.object(forKey: Keys.lastPromptDate) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSince >= minDaysBetweenPrompts else { return false }
        }

        return true
    }

    private func recordPromptShown() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastPromptDate)
        UserDefaults.standard.set(currentVersion, forKey: Keys.lastPromptedVersion)
        let prev = UserDefaults.standard.integer(forKey: Keys.promptCountThisVersion)
        UserDefaults.standard.set(prev + 1, forKey: Keys.promptCountThisVersion)
    }
}
