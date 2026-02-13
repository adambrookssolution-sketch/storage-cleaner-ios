import Photos
import Combine
import UIKit

/// Protocol abstraction over the photo library service for testability
protocol PhotoLibraryServicing {
    /// Scans the entire photo library, returning progress updates via publisher
    func scanLibrary() -> AnyPublisher<ScanProgress, Never>

    /// Fetches a thumbnail for a given asset identifier
    func thumbnail(for assetId: String, targetSize: CGSize) async -> UIImage?

    /// Returns total asset count without full scan
    func quickAssetCount() -> Int

    /// Cancels any ongoing scan
    func cancelScan()
}
