import Photos
import Combine
import UIKit

/// Encapsulates all PHPhotoLibrary permission logic
@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var status: PhotoPermissionStatus

    init() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.status = PhotoPermissionStatus(from: currentStatus)
    }

    /// Requests photo library access. Updates status reactively.
    func requestAccess() async {
        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        status = PhotoPermissionStatus(from: granted)
    }

    /// Refreshes the current status (call on app foreground return from Settings)
    func refreshStatus() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        status = PhotoPermissionStatus(from: currentStatus)
    }

    /// Opens iOS Settings for the app
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}
