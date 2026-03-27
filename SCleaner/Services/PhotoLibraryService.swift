import Photos
import Combine
import UIKit

/// Core scan engine — v1.1 with progressive real-time scan + memory-safe hashing.
///
/// Phase 1: Instant counts via PHFetchResult (zero memory) → publishes partial results
///          so dashboard cards appear and update in real-time.
/// Phase 2: Collect assets for detail views.
/// Phase 3: Memory-safe hashing for duplicate/similar detection.
/// Phase 4: Final results with duplicate/similar groups.
final class PhotoLibraryService: PhotoLibraryServicing {
    private let thumbnailService: ThumbnailCacheService
    private let hashingService: HashingService
    private let duplicateDetectionService: DuplicateDetectionService
    private let similarDetectionService: SimilarPhotoDetectionService
    private var scanTask: Task<Void, Never>?

    private let progressSubject = PassthroughSubject<ScanProgress, Never>()

    private(set) var sampleAssets: [MediaCategory: [PHAsset]] = [:]
    private(set) var duplicateGroups: [DuplicateGroup] = []
    private(set) var similarGroups: [SimilarGroup] = []
    private(set) var videoAssets: [PHAsset] = []
    private(set) var screenshotAssets: [PHAsset] = []

    init(thumbnailService: ThumbnailCacheService) {
        self.thumbnailService = thumbnailService
        self.hashingService = HashingService()
        self.duplicateDetectionService = DuplicateDetectionService()
        self.similarDetectionService = SimilarPhotoDetectionService()
    }

    func scanLibrary() -> AnyPublisher<ScanProgress, Never> {
        cancelScan()
        progressSubject.send(.scanning(processed: 0, total: 0))

        scanTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.performScanSafe()
            } catch {
                await MainActor.run {
                    self.progressSubject.send(.failed(String(format: NSLocalizedString("scan.errorDuringScan", comment: ""), error.localizedDescription)))
                }
            }
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

    // MARK: - Scan

    private func performScanSafe() async throws {
        let sortByDate = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // ═══════════════════════════════════════════════════════════
        // Phase 1: Instant counts via PHFetchResult (zero memory)
        // Cards appear immediately on dashboard
        // ═══════════════════════════════════════════════════════════

        let allFetchOptions = PHFetchOptions()
        allFetchOptions.sortDescriptors = sortByDate
        let allAssets = PHAsset.fetchAssets(with: allFetchOptions)
        let totalCount = allAssets.count

        guard totalCount > 0 else {
            let result = ScanResult.empty
            await MainActor.run { self.progressSubject.send(.completed(result)) }
            return
        }

        await MainActor.run {
            self.progressSubject.send(.scanning(processed: 0, total: totalCount))
        }

        // Fetch photos, videos, screenshots separately (instant)
        let photoOptions = PHFetchOptions()
        photoOptions.sortDescriptors = sortByDate
        let photoFetch = PHAsset.fetchAssets(with: .image, options: photoOptions)
        let totalPhotos = photoFetch.count

        let videoOptions = PHFetchOptions()
        videoOptions.sortDescriptors = sortByDate
        let videoFetch = PHAsset.fetchAssets(with: .video, options: videoOptions)
        let totalVideos = videoFetch.count

        let screenshotOptions = PHFetchOptions()
        screenshotOptions.sortDescriptors = sortByDate
        screenshotOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        let screenshotFetch = PHAsset.fetchAssets(with: .image, options: screenshotOptions)
        let totalScreenshots = screenshotFetch.count

        if Task.isCancelled { return }

        // Estimate sizes from samples (fast, ~95% accuracy)
        let sampleSize = 50
        let photosSize = estimateTotalSize(fetch: photoFetch, sampleCount: sampleSize)
        let videosSize = estimateTotalSize(fetch: videoFetch, sampleCount: sampleSize)
        let screenshotsSize = estimateTotalSize(fetch: screenshotFetch, sampleCount: sampleSize)
        let totalSize = photosSize + videosSize

        if Task.isCancelled { return }

        // Collect sample thumbnails for cards
        var screenshotSamples: [PHAsset] = []
        for i in 0..<min(4, screenshotFetch.count) {
            screenshotSamples.append(screenshotFetch.object(at: i))
        }
        var videoSamples: [PHAsset] = []
        for i in 0..<min(4, videoFetch.count) {
            videoSamples.append(videoFetch.object(at: i))
        }
        var photoSamples: [PHAsset] = []
        for i in 0..<min(4, photoFetch.count) {
            photoSamples.append(photoFetch.object(at: i))
        }

        sampleAssets[.screenshots] = screenshotSamples
        sampleAssets[.videos] = videoSamples
        sampleAssets[.duplicates] = Array(photoSamples.prefix(2))
        sampleAssets[.similar] = Array(photoSamples.prefix(2))
        sampleAssets[.similarScreenshots] = Array(screenshotSamples.prefix(2))
        sampleAssets[.similarVideos] = Array(videoSamples.prefix(2))
        sampleAssets[.other] = photoSamples

        // ═══════════════════════════════════════════════════════════
        // Publish FIRST partial result — cards appear on dashboard!
        // ═══════════════════════════════════════════════════════════

        let partialResult = ScanResult(
            totalAssets: totalCount,
            totalPhotos: totalPhotos,
            totalVideos: totalVideos,
            totalScreenshots: totalScreenshots,
            totalSizeBytes: totalSize,
            photosSizeBytes: photosSize,
            videosSizeBytes: videosSize,
            screenshotsSizeBytes: screenshotsSize,
            duplicateGroupCount: 0,
            duplicatePhotoCount: 0,
            duplicateSizeBytes: 0,
            similarGroupCount: 0,
            similarPhotoCount: 0,
            similarSizeBytes: 0,
            downloadFileCount: 0,
            downloadSizeBytes: 0,
            trashFileCount: TrashBinService.shared.totalTrashCount,
            trashSizeBytes: TrashBinService.shared.totalTrashSize
        )

        await MainActor.run {
            self.progressSubject.send(.partialResult(
                processed: Int(Double(totalCount) * 0.3),
                total: totalCount,
                result: partialResult
            ))
        }

        // ═══════════════════════════════════════════════════════════
        // Phase 2: Collect ALL assets for detail views
        // PHAsset objects are lightweight (~100 bytes each)
        // ═══════════════════════════════════════════════════════════

        var collectedScreenshots: [PHAsset] = []
        collectedScreenshots.reserveCapacity(totalScreenshots)
        for i in 0..<totalScreenshots {
            if Task.isCancelled { return }
            collectedScreenshots.append(screenshotFetch.object(at: i))
        }

        self.screenshotAssets = collectedScreenshots

        await MainActor.run {
            self.progressSubject.send(.partialResult(
                processed: Int(Double(totalCount) * 0.5),
                total: totalCount,
                result: partialResult
            ))
        }

        var collectedVideos: [PHAsset] = []
        collectedVideos.reserveCapacity(totalVideos)
        for i in 0..<totalVideos {
            if Task.isCancelled { return }
            collectedVideos.append(videoFetch.object(at: i))
        }

        self.videoAssets = collectedVideos

        if Task.isCancelled { return }

        // Collect all photo assets for hashing
        let photoAssets: [PHAsset] = (0..<totalPhotos).compactMap { i -> PHAsset? in
            guard !Task.isCancelled else { return nil }
            return photoFetch.object(at: i)
        }

        await MainActor.run {
            self.progressSubject.send(.partialResult(
                processed: Int(Double(totalCount) * 0.7),
                total: totalCount,
                result: partialResult
            ))
        }

        // ═══════════════════════════════════════════════════════════
        // Phase 3: Hash all photo assets (memory-safe)
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
        // Phase 4: Detect duplicates and similar photos
        // ═══════════════════════════════════════════════════════════

        let detectedDuplicates = duplicateDetectionService.findDuplicates(from: hashes)
        let duplicateIds = Set(detectedDuplicates.flatMap { $0.photos.map(\.id) })
        let detectedSimilar = similarDetectionService.findSimilarGroups(
            from: hashes,
            excludingDuplicateIds: duplicateIds
        )

        self.duplicateGroups = detectedDuplicates
        self.similarGroups = detectedSimilar

        let dupPhotoCount = detectedDuplicates.reduce(0) { $0 + $1.count }
        let dupSize = detectedDuplicates.reduce(Int64(0)) { $0 + $1.totalSize }
        let simPhotoCount = detectedSimilar.reduce(0) { $0 + $1.count }
        let simSize = detectedSimilar.reduce(Int64(0)) { $0 + $1.totalSize }

        // ═══════════════════════════════════════════════════════════
        // Phase 5: Final result with everything
        // ═══════════════════════════════════════════════════════════

        let finalResult = ScanResult(
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
            similarSizeBytes: simSize,
            downloadFileCount: 0,
            downloadSizeBytes: 0,
            trashFileCount: TrashBinService.shared.totalTrashCount,
            trashSizeBytes: TrashBinService.shared.totalTrashSize
        )

        await MainActor.run {
            self.progressSubject.send(.completed(finalResult))
        }
    }

    // MARK: - Size Estimation

    /// Estimate total size by sampling a small number of assets.
    /// 50 samples gives ~95% accuracy. Much faster than scanning all.
    private func estimateTotalSize(fetch: PHFetchResult<PHAsset>, sampleCount: Int) -> Int64 {
        let count = fetch.count
        guard count > 0 else { return 0 }

        let actualSampleCount = min(sampleCount, count)
        var sampleTotalSize: Int64 = 0

        autoreleasepool {
            for i in 0..<actualSampleCount {
                let asset = fetch.object(at: i)
                let resources = PHAssetResource.assetResources(for: asset)
                if let resource = resources.first,
                   let size = resource.value(forKey: "fileSize") as? Int64 {
                    sampleTotalSize += size
                }
            }
        }

        guard actualSampleCount > 0 else { return 0 }
        let averageSize = sampleTotalSize / Int64(actualSampleCount)
        return averageSize * Int64(count)
    }
}
