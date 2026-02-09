import Foundation

/// Immutable value type holding device storage breakdown
struct StorageInfo: Equatable {
    let totalBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    let photoLibraryBytes: Int64

    /// Usage ratio from 0.0 to 1.0
    var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    var totalGB: String { totalBytes.formattedGBInteger }
    var usedGB: String { usedBytes.formattedGBInteger }
    var formattedUsed: String { usedBytes.formattedSize }
    var formattedTotal: String { totalBytes.formattedSize }
    var formattedAvailable: String { availableBytes.formattedSize }

    /// Estimated photo library ratio of total storage
    var photoLibraryRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(photoLibraryBytes) / Double(totalBytes)
    }

    static let placeholder = StorageInfo(
        totalBytes: 128_000_000_000,
        usedBytes: 100_000_000_000,
        availableBytes: 28_000_000_000,
        photoLibraryBytes: 0
    )
}
