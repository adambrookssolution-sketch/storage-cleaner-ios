import Foundation

/// Represents each page in the onboarding flow
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case permission = 1
    case duplicatesTutorial = 2
    case storageOverview = 3

    var id: Int { rawValue }

    /// Total number of steps (for progress indicator)
    static var totalCount: Int { allCases.count }

    /// Whether this is the last step
    var isLast: Bool {
        self == OnboardingStep.allCases.last
    }
}
