import Photos
import UIKit

/// Computes perceptual hashes (dHash) for PHAssets in batches with progress reporting.
/// Optimized for low memory footprint on devices with 15,000+ photos.
final class HashingService {

    /// Hashes an array of PHAssets, returning PhotoHash structs.
    /// Only processes images (skips videos).
    func hashAssets(
        _ assets: [PHAsset],
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoHash] {
        let imageAssets = assets.filter { $0.mediaType == .image }
        let total = imageAssets.count
        guard total > 0 else { return [] }

        let batchSize = AppConstants.Hashing.hashBatchSize
        var allHashes: [PhotoHash] = []
        allHashes.reserveCapacity(total)

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        let targetSize = AppConstants.Hashing.hashThumbnailSize  // 72x72

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + batchSize, total)

            // Process each asset sequentially within the batch to control memory
            for i in batchStart..<batchEnd {
                if Task.isCancelled { break }

                let asset = imageAssets[i]

                let photoHash: PhotoHash? = await withCheckedContinuation { continuation in
                    var hasResumed = false

                    manager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        // Prevent double-resume: take only the first valid callback
                        guard !hasResumed else { return }
                        hasResumed = true

                        guard let image else {
                            continuation.resume(returning: nil)
                            return
                        }

                        var result: PhotoHash?
                        autoreleasepool {
                            let hashValue = image.dHash()
                            result = PhotoHash(
                                id: asset.localIdentifier,
                                hash: hashValue,
                                creationDate: asset.creationDate,
                                fileSize: 0,
                                pixelWidth: asset.pixelWidth,
                                pixelHeight: asset.pixelHeight,
                                isFavorite: asset.isFavorite,
                                mediaSubtypes: asset.mediaSubtypes.rawValue
                            )
                        }
                        continuation.resume(returning: result)
                    }
                }

                if let photoHash {
                    allHashes.append(photoHash)
                }
            }

            progressHandler(min(batchEnd, total), total)
            await Task.yield()
        }

        return allHashes
    }
}
