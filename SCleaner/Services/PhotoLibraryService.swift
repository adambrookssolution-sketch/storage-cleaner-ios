import Photos
import Combine
import UIKit

/// Core scan engine: fetches all PHAssets, categorizes them, calculates sizes,
/// computes perceptual hashes, detects duplicates/similar photos,
/// publishes progress incrementally, and collects sample assets for dashboard thumbnails.
///
/// Optimized for devices with 15,000+ photos: uses autoreleasepool batching,
/// defers expensive file-size lookups for hashing, and yields between phases.
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

    /// All video assets sorted by file size descending (available after scan)
    private(set) var videoAssets: [PHAsset] = []
    /// All screenshot assets sorted by date descending (available after scan)
    private(set) var screenshotAssets: [PHAsset] = []

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
        var photoAssets: [PHAsset] = []
        var allVideoAssets: [PHAsset] = []
        var allScreenshotAssets: [PHAsset] = []

        let batchSize = 200
        let updateEvery = 2

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
                        allVideoAssets.append(asset)
                        if videoSamples.count < 4 { videoSamples.append(asset) }
                    } else if asset.isScreenshot {
                        totalScreenshots += 1
                        screenshotsSize += size
                        totalPhotos += 1
                        photosSize += size
                        allScreenshotAssets.append(asset)
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
            if batchIndex % updateEvery == 0 || batchEnd == totalCount {
                await MainActor.run {
                    self.progressSubject.send(.scanning(processed: currentProcessed, total: totalCount))
                }
            }
        }

        if Task.isCancelled { return }

        // Sort collected assets for detail views
        self.videoAssets = allVideoAssets.sorted { $0.estimatedFileSize > $1.estimatedFileSize }
        self.screenshotAssets = allScreenshotAssets.sorted {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }

        // ═══════════════════════════════════════════════════════════
        // Phase 2: Hash all photo assets (memory-optimized)
        // ═══════════════════════════════════════════════════════════

        await MainActor.run {
            self.progressSubject.send(.hashing(processed: 0, total: photoAssets.count))
        }

        var hashes = await hashingService.hashAssets(photoAssets) { [weak self] processed, total in
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

        // ═══════════════════════════════════════════════════════════
        // Phase 3.5: Populate file sizes ONLY for grouped photos
        // (avoids calling PHAssetResource for all 15K+ photos during hashing)
        // ═══════════════════════════════════════════════════════════

        let groupedIds = duplicateIds.union(Set(detectedSimilar.flatMap { $0.photos.map(\.id) }))

        if !groupedIds.isEmpty {
            var idToIndex: [String: Int] = [:]
            idToIndex.reserveCapacity(hashes.count)
            for (i, h) in hashes.enumerated() {
                idToIndex[h.id] = i
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(groupedIds), options: nil)
            fetchResult.enumerateObjects { asset, _, _ in
                autoreleasepool {
                    if let idx = idToIndex[asset.localIdentifier] {
                        let resources = PHAssetResource.assetResources(for: asset)
                        if let resource = resources.first,
                           let size = resource.value(forKey: "fileSize") as? Int64 {
                            hashes[idx].fileSize = size
                        }
                    }
                }
            }
        }

        // Rebuild groups with updated file sizes
        let finalDuplicates = duplicateDetectionService.findDuplicates(from: hashes)
        let finalDuplicateIds = Set(finalDuplicates.flatMap { $0.photos.map(\.id) })
        let finalSimilar = similarDetectionService.findSimilarGroups(
            from: hashes,
            excludingDuplicateIds: finalDuplicateIds
        )

        // Store results for navigation
        self.duplicateGroups = finalDuplicates
        self.similarGroups = finalSimilar

        // Calculate totals
        let dupPhotoCount = finalDuplicates.reduce(0) { $0 + $1.count }
        let dupSize = finalDuplicates.reduce(Int64(0)) { $0 + $1.totalSize }
        let simPhotoCount = finalSimilar.reduce(0) { $0 + $1.count }
        let simSize = finalSimilar.reduce(Int64(0)) { $0 + $1.totalSize }

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
            duplicateGroupCount: finalDuplicates.count,
            duplicatePhotoCount: dupPhotoCount,
            duplicateSizeBytes: dupSize,
            similarGroupCount: finalSimilar.count,
            similarPhotoCount: simPhotoCount,
            similarSizeBytes: simSize,
            downloadFileCount: 0,
            downloadSizeBytes: 0,
            trashFileCount: TrashBinService.shared.totalTrashCount,
            trashSizeBytes: TrashBinService.shared.totalTrashSize
        )

        await MainActor.run {
            self.progressSubject.send(.completed(result))
        }
    }
}
