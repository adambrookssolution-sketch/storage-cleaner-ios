import Photos
import UIKit

/// Computes perceptual hashes (dHash) for PHAssets in batches with progress reporting.
/// Target: >500 photos/sec on iPhone 12+.
final class HashingService {
    private let imageManager = PHCachingImageManager()
    private let requestOptions: PHImageRequestOptions

    init() {
        requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true     // We control threading via Task
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = false // Skip iCloud for speed
    }

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
        let targetSize = AppConstants.Hashing.hashThumbnailSize
        var allHashes: [PhotoHash] = []
        allHashes.reserveCapacity(total)
        var failedImageCount = 0

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            if Task.isCancelled { break }

            let batchEnd = min(batchStart + batchSize, total)
            var batchHashes: [PhotoHash] = []

            autoreleasepool {
                for i in batchStart..<batchEnd {
                    let asset = assets[i]

                    // Only hash photos
                    guard asset.mediaType == .image else { continue }

                    // Synchronous thumbnail request
                    var resultImage: UIImage?
                    imageManager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: requestOptions
                    ) { image, info in
                        resultImage = image
                        if image == nil {
                            print("[HashingService] FAILED image for asset \(asset.localIdentifier), info: \(String(describing: info))")
                        }
                    }

                    guard let image = resultImage else {
                        failedImageCount += 1
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
                    batchHashes.append(photoHash)
                }
            }

            allHashes.append(contentsOf: batchHashes)
            progressHandler(min(batchEnd, total), total)
        }

        print("[HashingService] Done: \(allHashes.count) hashed, \(failedImageCount) failed")
        for h in allHashes {
            print("[HashingService] hash=\(h.hash) px=\(h.pixelWidth)x\(h.pixelHeight) size=\(h.fileSize)")
        }

        return allHashes
    }
}
