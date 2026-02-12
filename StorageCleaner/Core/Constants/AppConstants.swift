import Foundation
import CoreGraphics

enum AppConstants {
    enum Storage {
        static let thumbnailSize = CGSize(width: 150, height: 150)
        static let categoryCardThumbnailSize = CGSize(width: 180, height: 180)
        static let scanBatchSize = 100
        static let maxConcurrentThumbnailRequests = 20
        static let progressUpdateInterval = 3 // Update UI every N batches
    }

    enum UI {
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 14
        static let horizontalPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 16
        static let badgeCornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 56
        static let iconSize: CGFloat = 72
    }

    enum Onboarding {
        static let totalSteps = 4
        static let tutorialSelectionDelay: TimeInterval = 1.0
        static let tutorialRemovalDelay: TimeInterval = 2.5
    }

    enum URLs {
        static let privacyPolicy = "https://storagecleaner.app/privacy"
        static let termsOfUse = "https://storagecleaner.app/terms"
        static let instagram = "https://instagram.com/storagecleaner"
        static let supportEmail = "support@storagecleaner.app"
    }

    enum AppInfo {
        static let appName = "StorageCleaner"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
