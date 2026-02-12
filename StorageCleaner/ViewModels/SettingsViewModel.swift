import SwiftUI
@preconcurrency import StoreKit

/// ViewModel for the settings screen
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showMailComposer = false

    func openPrivacyPolicy() {
        guard let url = URL(string: AppConstants.URLs.privacyPolicy) else { return }
        UIApplication.shared.open(url)
    }

    func openTermsOfUse() {
        guard let url = URL(string: AppConstants.URLs.termsOfUse) else { return }
        UIApplication.shared.open(url)
    }

    func rateApp() {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            AppStore.requestReview(in: scene)
        }
    }

    func shareApp() {
        let text = "Confira o StorageCleaner - organize suas fotos e libere espaço!"
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // iPad popover support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
        }

        rootVC.present(activityVC, animated: true)
    }

    func openInstagram() {
        guard let url = URL(string: AppConstants.URLs.instagram) else { return }
        UIApplication.shared.open(url)
    }

    func contactSupport() {
        let email = AppConstants.URLs.supportEmail
        guard let url = URL(string: "mailto:\(email)?subject=StorageCleaner%20Suporte") else { return }
        UIApplication.shared.open(url)
    }

    func restorePurchases() {
        // M4: RevenueCat restore implementation
        // M1: No-op — will be connected in Milestone 4
    }

    var appVersion: String {
        "\(AppConstants.AppInfo.version) (\(AppConstants.AppInfo.buildNumber))"
    }
}
