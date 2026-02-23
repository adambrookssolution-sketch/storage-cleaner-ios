import Photos
import UIKit

/// Computes perceptual hashes (dHash) for PHAssets in batches with progress reporting.
/// Target: >500 photos/sec on iPhone 12+.
final class HashingService {

    /// Hashes an array of PHAssets, returning PhotoHash structs.
    /// Only processes images (skips videos).
    /// - Parameters:
    ///   - assets: PHAssets to hash
    ///   - progressHandler: Called with (processed, total) after each batch
    /// - Returns: Array of PhotoHash for successfully hashed assets
    func hashAssets(
        _ assets: [PHAsset],
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoHash] {
        let total = assets.count
        guard total > 0 else {
            print("[HashingService] No assets to hash")
            return []
        }

        print("[HashingService] Starting hashing of \(total) photo assets")
        let batchSize = AppConstants.Hashing.hashBatchSize
        var allHashes: [PhotoHash] = []
        allHashes.reserveCapacity(total)
        var failedImageCount = 0

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + batchSize, total)

            for i in batchStart..<batchEnd {
                let asset = assets[i]

                // Only hash photos
                guard asset.mediaType == .image else { continue }

                let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                    var hasResumed = false
                    manager.requestImage(
                        for: asset,
                        targetSize: CGSize(width: 200, height: 200),
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        guard !hasResumed else { return }
                        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                        let error = info?[PHImageErrorKey] as? Error
                        if !isDegraded || isCancelled || error != nil {
                            hasResumed = true
                            continuation.resume(returning: image)
                        }
                    }
                }

                guard let image else {
                    failedImageCount += 1
                    print("[HashingService] FAILED asset \(asset.localIdentifier)")
                    continue
                }

                let hashValue = image.dHash()
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
            }

            progressHandler(min(batchEnd, total), total)
        }

        print("[HashingService] Done: \(allHashes.count) hashed, \(failedImageCount) failed")
        for h in allHashes {
            print("[HashingService] hash=\(h.hash) px=\(h.pixelWidth)x\(h.pixelHeight) size=\(h.fileSize)")
        }

        return allHashes
    }
}
