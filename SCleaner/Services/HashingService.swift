import Photos
import UIKit

/// Computes perceptual hashes (dHash) for PHAssets in batches with progress reporting.
/// Optimized for memory: uses small thumbnail size, yields between batches.
final class HashingService {

    /// Hashes an array of PHAssets, returning PhotoHash structs.
    /// Only processes images (skips videos).
    func hashAssets(
        _ assets: [PHAsset],
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoHash] {
        let total = assets.count
        guard total > 0 else {
            #if DEBUG
            print("[HashingService] No assets to hash")
            #endif
            return []
        }

        #if DEBUG
        print("[HashingService] Starting hashing of \(total) photo assets")
        #endif
        let batchSize = AppConstants.Hashing.hashBatchSize
        var allHashes: [PhotoHash] = []
        allHashes.reserveCapacity(min(total, 10000))
        var failedImageCount = 0

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        // Use highQualityFormat to guarantee a single non-degraded callback.
        // fastFormat can deliver a degraded image first, then a final image second —
        // with the old logic this caused continuation to never resume on the first
        // callback (isDegraded=true), hanging the Task indefinitely on large libraries.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        let targetSize = AppConstants.Hashing.hashThumbnailSize

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + batchSize, total)

            for i in batchStart..<batchEnd {
                if Task.isCancelled { break }

                let asset = assets[i]

                // Only hash photos
                guard asset.mediaType == .image else { continue }

                let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                    var hasResumed = false
                    manager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        // Guard against double-resume (PHImageManager can call back twice
                        // in opportunistic/fastFormat mode)
                        guard !hasResumed else { return }

                        let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                        let hasError = info?[PHImageErrorKey] as? Error != nil

                        // With highQualityFormat, this callback fires exactly once with
                        // the final image (or nil on error/cancel). Always resume here.
                        if isCancelled || hasError {
                            hasResumed = true
                            continuation.resume(returning: nil)
                        } else {
                            hasResumed = true
                            continuation.resume(returning: image)
                        }
                    }
                }

                if let image {
                    // Compute hash synchronously inside autoreleasepool
                    let hashValue = autoreleasepool { image.dHash() }
                    let photoHash = PhotoHash(
                        id: asset.localIdentifier,
                        hash: hashValue,
                        creationDate: asset.creationDate,
                        fileSize: asset.estimatedFileSize,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        isFavorite: asset.isFavorite,
                        mediaSubtypes: asset.mediaSubtypes.rawValue
                    )
                    allHashes.append(photoHash)
                } else {
                    failedImageCount += 1
                }
            }

            progressHandler(min(batchEnd, total), total)

            // Yield between batches so the scheduler can process UI events
            // and prevent the watchdog from killing the app on slower devices.
            await Task.yield()
        }

        #if DEBUG
        print("[HashingService] Done: \(allHashes.count) hashed, \(failedImageCount) failed")
        #endif

        return allHashes
    }
}
