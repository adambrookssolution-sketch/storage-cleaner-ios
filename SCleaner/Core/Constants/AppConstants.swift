import Foundation
import CoreGraphics

enum AppConstants {
    enum Storage {
        static let thumbnailSize = CGSize(width: 150, height: 150)
        static let categoryCardThumbnailSize = CGSize(width: 180, height: 180)
        static let scanBatchSize = 200
        static let maxConcurrentThumbnailRequests = 20
        static let progressUpdateInterval = 2
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
        static let privacyPolicy = "https://vortexcleaner.com/privacy"
        static let termsOfUse = "https://vortexcleaner.com/terms"
        static let instagram = "https://instagram.com/vortexcleaner"
        static let supportEmail = "support@vortexcleaner.com"
    }

    enum Hashing {
        static let hashImageWidth = 9
        static let hashImageHeight = 8
        static let duplicateThreshold = 10
        static let similarThreshold = 20
        static let hashBatchSize = 100
        static let hashThumbnailSize = CGSize(width: 72, height: 72)
    }

    enum Downloads {
        static let minimumFileSizeBytes: Int64 = 10 * 1_048_576
        static let staleMonths = 6
        static let bookmarkKey = "SCleaner_DownloadsFolderBookmark"
    }

    enum TrashBin {
        static let purgeAfterDays = 30
        static let directoryName = "TrashBin"
        static let manifestFileName = "manifest.json"
        static let maxTrashSizeWarningBytes: Int64 = 1_073_741_824
    }

    enum RevenueCat {
        static let apiKey = "appl_hEiAkPrIaTecEddkQYBdHYdHdQF"
        static let entitlementId = "Vortex Cleaner Pro"
    }

    enum Subscription {
        static let paywallEnabled = true

        // 3 subscription products
        static let weeklyProductId = "com.vortexcleaner.weekly"           // $7.99/sem (intro $0.99)
        static let monthlyProductId = "com.vortexcleaner.monthly"         // $28/mês
        static let freeTrialProductId = "com.vortexcleaner.weekly.trial"   // $6.99/sem (intro 3 dias grátis)

        static let allProductIds: [String] = [weeklyProductId, monthlyProductId, freeTrialProductId]

        static func tier(for productId: String) -> SubscriptionTier? {
            switch productId {
            case weeklyProductId: return .weekly
            case monthlyProductId: return .monthly
            case freeTrialProductId: return .freeTrial
            default: return nil
            }
        }

        static let freeDeleteLimit = 5
        static let trialDays = 3
    }

    enum AppInfo {
        static let appName = "Vortex Cleaner"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
