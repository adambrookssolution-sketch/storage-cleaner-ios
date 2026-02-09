import Photos

/// Clean wrapper around PHAuthorizationStatus for the view layer
enum PhotoPermissionStatus: Equatable {
    case notDetermined
    case authorized       // full access
    case limited          // iOS 14+ limited access
    case denied
    case restricted

    init(from phStatus: PHAuthorizationStatus) {
        switch phStatus {
        case .notDetermined: self = .notDetermined
        case .authorized:    self = .authorized
        case .limited:       self = .limited
        case .denied:        self = .denied
        case .restricted:    self = .restricted
        @unknown default:    self = .denied
        }
    }

    /// Whether the app has some level of photo access
    var hasAccess: Bool {
        self == .authorized || self == .limited
    }

    /// Whether the user explicitly denied access
    var isDenied: Bool {
        self == .denied || self == .restricted
    }
}
