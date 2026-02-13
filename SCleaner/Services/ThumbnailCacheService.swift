import Photos
import UIKit

/// Wraps PHCachingImageManager for efficient thumbnail loading
final class ThumbnailCacheService {
    private let cachingManager = PHCachingImageManager()
    private let requestOptions: PHImageRequestOptions

    init() {
        requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true // for iCloud photos
    }

    /// Loads thumbnail for a PHAsset local identifier
    func loadThumbnail(assetId: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId], options: nil
        ).firstObject else {
            return nil
        }
        return await loadThumbnail(for: asset, targetSize: targetSize)
    }

    /// Loads thumbnail for a PHAsset with double-callback safety
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            cachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? Error

                // Resume on final callback (non-degraded), or on error/cancel
                if !isDegraded || isCancelled || error != nil {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// Start caching thumbnails for a set of assets (for prefetching in scroll)
    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        )
    }

    /// Stop caching thumbnails
    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        )
    }

    /// Reset all cached images
    func stopAllCaching() {
        cachingManager.stopCachingImagesForAllAssets()
    }
}
