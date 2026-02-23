import Photos
import Combine
import UIKit

/// Core scan engine: fetches all PHAssets, categorizes them, calculates sizes,
/// computes perceptual hashes, detects duplicates/similar photos,
/// publishes progress incrementally, and collects sample assets for dashboard thumbnails
final class PhotoLibraryService: PhotoLibraryServicing {
    private let thumbnailService: ThumbnailCacheService
    private let hashingService: HashingService
    private let duplicateDetectionService: DuplicateDetectionService
    private let similarDetectionService: SimilarPhotoDetectionService
    private var scanTask: Task<Void, Never>?

    /// Published scan state
    private let progressSubject = PassthroughSubject<ScanProgress, Never>()

    /// Sample assets for dashboard card thumbnails (first 4 per category)
    private(set) var sampleAssets: [MediaCategory: [PHAsset]] = [:]

    /// M2: Detected duplicate and similar groups (available after scan completes)
    private(set) var duplicateGroups: [DuplicateGroup] = []
    private(set) var similarGroups: [SimilarGroup] = []

    init(thumbnailService: ThumbnailCacheService) {
        self.thumbnailService = thumbnailService
        self.hashingService = HashingService()
        self.duplicateDetectionService = DuplicateDetectionService()
        self.similarDetectionService = SimilarPhotoDetectionService()
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
        // ═══════════════════════════════════════════════════════════
        // Phase 1: Fetch & Categorize all assets
        // ═══════════════════════════════════════════════════════════

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allAssets = PHAsset.fetchAssets(with: fetchOptions)
        let totalCount = allAssets.count

        guard totalCount > 0 else {
            let result = ScanResult.empty
            await MainActor.run { self.progressSubject.send(.completed(result)) }
            return
        }

        var totalPhotos = 0
        var totalVideos = 0
        var totalScreenshots = 0
        var totalSize: Int64 = 0
        var photosSize: Int64 = 0
        var videosSize: Int64 = 0
        var screenshotsSize: Int64 = 0

        var screenshotSamples: [PHAsset] = []
        var videoSamples: [PHAsset] = []
        var photoSamples: [PHAsset] = []
        var photoAssets: [PHAsset] = []  // Collect all photo assets for hashing

        let batchSize = AppConstants.Storage.scanBatchSize
        let updateInterval = AppConstants.Storage.progressUpdateInterval

        for batchStart in stride(from: 0, to: totalCount, by: batchSize) {
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
                        photoAssets.append(asset)
                    } else if asset.isPhoto {
                        totalPhotos += 1
                        photosSize += size
                        if photoSamples.count < 4 { photoSamples.append(asset) }
                        photoAssets.append(asset)
                    }
                }
            }

            let currentProcessed = batchEnd
            let batchIndex = batchStart / batchSize
            if batchIndex % updateInterval == 0 || batchEnd == totalCount {
                await MainActor.run {
                    self.progressSubject.send(.scanning(processed: currentProcessed, total: totalCount))
                }
            }
        }

        if Task.isCancelled { return }

        print("[PhotoLibrary] Phase 1 done: \(totalPhotos) photos, \(totalVideos) videos, \(totalScreenshots) screenshots, photoAssets=\(photoAssets.count)")

        // ═══════════════════════════════════════════════════════════
        // Phase 2: Hash all photo assets
        // ═══════════════════════════════════════════════════════════

        await MainActor.run {
            self.progressSubject.send(.hashing(processed: 0, total: photoAssets.count))
        }

        let hashes = await hashingService.hashAssets(photoAssets) { [weak self] processed, total in
            guard let self else { return }
            Task { @MainActor in
                self.progressSubject.send(.hashing(processed: processed, total: total))
            }
        }

        if Task.isCancelled { return }

        // ═══════════════════════════════════════════════════════════
        // Phase 3: Detect duplicates and similar photos
        // ═══════════════════════════════════════════════════════════

        let detectedDuplicates = duplicateDetectionService.findDuplicates(from: hashes)

        let duplicateIds = Set(detectedDuplicates.flatMap { $0.photos.map(\.id) })
        let detectedSimilar = similarDetectionService.findSimilarGroups(
            from: hashes,
            excludingDuplicateIds: duplicateIds
        )

        print("[PhotoLibrary] Phase 3 done: \(detectedDuplicates.count) dup groups, \(detectedSimilar.count) similar groups")

        // Store results for navigation
        self.duplicateGroups = detectedDuplicates
        self.similarGroups = detectedSimilar

        // Calculate totals
        let dupPhotoCount = detectedDuplicates.reduce(0) { $0 + $1.count }
        let dupSize = detectedDuplicates.reduce(Int64(0)) { $0 + $1.totalSize }
        let simPhotoCount = detectedSimilar.reduce(0) { $0 + $1.count }
        let simSize = detectedSimilar.reduce(Int64(0)) { $0 + $1.totalSize }

        // ═══════════════════════════════════════════════════════════
        // Phase 4: Build results and publish
        // ═══════════════════════════════════════════════════════════

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
            screenshotsSizeBytes: screenshotsSize,
            duplicateGroupCount: detectedDuplicates.count,
            duplicatePhotoCount: dupPhotoCount,
            duplicateSizeBytes: dupSize,
            similarGroupCount: detectedSimilar.count,
            similarPhotoCount: simPhotoCount,
            similarSizeBytes: simSize
        )

        await MainActor.run {
            self.progressSubject.send(.completed(result))
        }
    }
}
