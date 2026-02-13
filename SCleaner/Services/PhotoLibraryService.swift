import Photos
import Combine
import UIKit

/// Core scan engine: fetches all PHAssets, categorizes them, calculates sizes,
/// publishes progress incrementally, and collects sample assets for dashboard thumbnails
final class PhotoLibraryService: PhotoLibraryServicing {
    private let thumbnailService: ThumbnailCacheService
    private var scanTask: Task<Void, Never>?

    /// Published scan state
    private let progressSubject = PassthroughSubject<ScanProgress, Never>()

    /// Sample assets for dashboard card thumbnails (first 4 per category)
    private(set) var sampleAssets: [MediaCategory: [PHAsset]] = [:]

    init(thumbnailService: ThumbnailCacheService) {
        self.thumbnailService = thumbnailService
    }

    // MARK: - PhotoLibraryServicing

    func scanLibrary() -> AnyPublisher<ScanProgress, Never> {
        cancelScan()
        progressSubject.send(.scanning(processed: 0, total: 0))

        scanTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.performScan()
        }

        return progressSubject.eraseToAnyPublisher()
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    func quickAssetCount() -> Int {
        PHAsset.fetchAssets(with: nil).count
    }

    func thumbnail(for assetId: String, targetSize: CGSize) async -> UIImage? {
        await thumbnailService.loadThumbnail(assetId: assetId, targetSize: targetSize)
    }

    // MARK: - Private Scan Logic

    private func performScan() async {
        // Step 1: Fetch ALL assets
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        let totalCount = allAssets.count

        guard totalCount > 0 else {
            let result = ScanResult.empty
            await MainActor.run { self.progressSubject.send(.completed(result)) }
            return
        }

        // Step 2: Enumerate in batches using Sendable-safe counters
        var totalPhotos = 0
        var totalVideos = 0
        var totalScreenshots = 0
        var totalSize: Int64 = 0
        var photosSize: Int64 = 0
        var videosSize: Int64 = 0
        var screenshotsSize: Int64 = 0

        // Sample assets for dashboard card thumbnails (collect first 4 per category)
        var screenshotSamples: [PHAsset] = []
        var videoSamples: [PHAsset] = []
        var photoSamples: [PHAsset] = []

        let batchSize = AppConstants.Storage.scanBatchSize
        let updateInterval = AppConstants.Storage.progressUpdateInterval

        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
            // Check cancellation
            if Task.isCancelled { return }

            let batchEnd = min(batchStart + batchSize, totalCount)

            autoreleasepool {
                for i in batchStart..<batchEnd {
                    let asset = allAssets.object(at: i)
                    let size = asset.estimatedFileSize
                    totalSize += size

                    if asset.isVideo {
                        totalVideos += 1
                        videosSize += size
                        if videoSamples.count < 4 { videoSamples.append(asset) }
                    } else if asset.isScreenshot {
                        totalScreenshots += 1
                        screenshotsSize += size
                        totalPhotos += 1
                        photosSize += size
                        if screenshotSamples.count < 4 { screenshotSamples.append(asset) }
                    } else if asset.isPhoto {
                        totalPhotos += 1
                        photosSize += size
                        if photoSamples.count < 4 { photoSamples.append(asset) }
                    }
                }
            }

            // Publish progress update (throttled to avoid UI flooding)
            let currentProcessed = batchEnd
            let batchIndex = batchStart / batchSize
            if batchIndex % updateInterval == 0 || batchEnd == totalCount {
                await MainActor.run {
                    self.progressSubject.send(.scanning(processed: currentProcessed, total: totalCount))
                }
            }
        }

        // Store sample assets for dashboard card thumbnails
        sampleAssets[.screenshots] = screenshotSamples
        sampleAssets[.similarScreenshots] = Array(screenshotSamples.prefix(2))
        sampleAssets[.videos] = videoSamples
        sampleAssets[.similarVideos] = Array(videoSamples.prefix(2))
        sampleAssets[.duplicates] = Array(photoSamples.prefix(2))
        sampleAssets[.similar] = Array(photoSamples.prefix(2))
        sampleAssets[.other] = photoSamples

        let result = ScanResult(
            totalAssets: totalCount,
            totalPhotos: totalPhotos,
            totalVideos: totalVideos,
            totalScreenshots: totalScreenshots,
            totalSizeBytes: totalSize,
            photosSizeBytes: photosSize,
            videosSizeBytes: videosSize,
            screenshotsSizeBytes: screenshotsSize
        )

        await MainActor.run {
            self.progressSubject.send(.completed(result))
        }
    }
}
