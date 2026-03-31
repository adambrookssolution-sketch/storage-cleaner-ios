import Photos
import UIKit

/// Wraps PHCachingImageManager for efficient thumbnail loading.
/// Uses an LRU cache with a hard limit to prevent memory explosion on large libraries.
/// Throttles concurrent image requests to avoid saturating the system.
@MainActor
final class ThumbnailCacheService {
    private let cachingManager = PHCachingImageManager()
    private let requestOptions: PHImageRequestOptions

    /// LRU cache: stores up to `maxCacheCount` thumbnails.
    /// At 150x150 @2x, each UIImage is ~180KB. 200 items ≈ 36MB — safe on any device.
    private var cache: [String: UIImage] = [:]
    private var accessOrder: [String] = []
    private let maxCacheCount = 200

    /// Semaphore to limit concurrent image requests (prevents system resource exhaustion).
    /// @MainActor isolation guarantees these are always accessed from one thread.
    private let concurrencyLimit: Int = 6
    private var activeRequests = 0
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []

    init() {
        requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true
    }

    // MARK: - Cache Access

    /// Returns cached thumbnail if available, without loading
    func cachedThumbnail(for assetId: String) -> UIImage? {
        if let image = cache[assetId] {
            if let index = accessOrder.firstIndex(of: assetId) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(assetId)
            return image
        }
        return nil
    }

    /// Removes a thumbnail from cache (call on onDisappear for memory relief)
    func evict(assetId: String) {
        cache.removeValue(forKey: assetId)
        accessOrder.removeAll { $0 == assetId }
    }

    /// Evict all thumbnails not in the given set of visible IDs
    func evictExcept(visibleIds: Set<String>) {
        let toRemove = cache.keys.filter { !visibleIds.contains($0) }
        for key in toRemove {
            cache.removeValue(forKey: key)
        }
        accessOrder.removeAll { !visibleIds.contains($0) }
    }

    // MARK: - Loading

    /// Loads thumbnail for a PHAsset local identifier, with concurrency throttling and LRU caching.
    func loadThumbnail(assetId: String, targetSize: CGSize) async -> UIImage? {
        if let cached = cachedThumbnail(for: assetId) {
            return cached
        }

        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId], options: nil
        ).firstObject else {
            return nil
        }

        return await loadThumbnail(for: asset, targetSize: targetSize)
    }

    /// Loads thumbnail for a PHAsset with concurrency throttling, double-callback safety, and LRU caching.
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let assetId = asset.localIdentifier

        if let cached = cachedThumbnail(for: assetId) {
            return cached
        }

        await acquireSlot()

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            var hasResumed = false
            cachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, info in
                // opportunistic mode fires twice: once degraded, once final.
                // Only resume on the final (non-degraded) callback, or on error/cancel.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] as? Error != nil

                guard !hasResumed else { return }

                if isCancelled || hasError {
                    hasResumed = true
                    continuation.resume(returning: nil)
                } else if !isDegraded {
                    // Final high-quality image delivered — resume now
                    hasResumed = true
                    continuation.resume(returning: image)
                }
                // isDegraded=true with no error/cancel: skip, wait for final callback
            }
        }

        releaseSlot()

        if let image {
            storeThumbnail(image, forKey: assetId)
        }

        return image
    }

    // MARK: - LRU Eviction

    private func storeThumbnail(_ image: UIImage, forKey key: String) {
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return
        }

        while cache.count >= maxCacheCount, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        cache[key] = image
        accessOrder.append(key)
    }

    // MARK: - Concurrency Throttling

    private func acquireSlot() async {
        if activeRequests < concurrencyLimit {
            activeRequests += 1
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pendingContinuations.append(continuation)
        }
        activeRequests += 1
    }

    private func releaseSlot() {
        activeRequests -= 1
        if let next = pendingContinuations.first {
            pendingContinuations.removeFirst()
            next.resume()
        }
    }

    // MARK: - PHCachingImageManager helpers

    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        )
    }

    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        )
    }

    func stopAllCaching() {
        cachingManager.stopCachingImagesForAllAssets()
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        cachingManager.stopCachingImagesForAllAssets()
    }
}
