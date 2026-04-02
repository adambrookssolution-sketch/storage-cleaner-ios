import Photos
import Combine
import UIKit

/// Core scan engine — v2.0 with progressive real-time scan, memory-safe hashing,
/// file-size caching, and background-threaded duplicate/similar detection.
///
/// Phase 1: Instant counts via PHFetchResult (zero memory) → publishes partial results
///          so dashboard cards appear and update in real-time.
/// Phase 2: Collect assets for detail views (with autoreleasepool + size caching).
/// Phase 3: Memory-safe hashing for duplicate/similar detection.
/// Phase 4: Detect duplicates and similar in detached background task.
/// Phase 5: Final results with duplicate/similar groups.
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

    /// Pre-computed file sizes keyed by asset localIdentifier.
    /// Populated during Phase 2 so ViewModels never touch disk for sizes.
    private(set) var fileSizeCache: [String: Int64] = [:]

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

        // Estimate sizes from samples (Phase 1 quick estimate for partial results)
        // NOTE: photoFetch (.image) already includes screenshots, so do NOT add screenshotsSize
        // to avoid double-counting. screenshotsSize is tracked separately for the category card.
        let sampleSize = 50
        let photosSize = estimateTotalSize(fetch: photoFetch, sampleCount: sampleSize)
        let videosSize = estimateTotalSize(fetch: videoFetch, sampleCount: sampleSize)
        let screenshotsSize = estimateTotalSize(fetch: screenshotFetch, sampleCount: sampleSize)

        // photos already includes screenshots, so total = photos + videos only
        let totalSize = photosSize + videosSize

        if Task.isCancelled { return }

        // Collect sample thumbnails for dashboard cards
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
        // Uses autoreleasepool batches to prevent ObjC object buildup.
        // Computes file sizes inline and stores in fileSizeCache.
        // ═══════════════════════════════════════════════════════════

        var sizeCache: [String: Int64] = [:]
        sizeCache.reserveCapacity(totalScreenshots + totalVideos + totalPhotos)

        // --- Screenshots ---
        var collectedScreenshots: [PHAsset] = []
        collectedScreenshots.reserveCapacity(totalScreenshots)
        let screenshotBatchSize = 500
        for batchStart in stride(from: 0, to: totalScreenshots, by: screenshotBatchSize) {
            if Task.isCancelled { return }
            autoreleasepool {
                let batchEnd = min(batchStart + screenshotBatchSize, totalScreenshots)
                for j in batchStart..<batchEnd {
                    let asset = screenshotFetch.object(at: j)
                    collectedScreenshots.append(asset)
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let size = resources.first?.value(forKey: "fileSize") as? Int64 {
                        sizeCache[asset.localIdentifier] = size
                    }
                }
            }
        }
        self.screenshotAssets = collectedScreenshots
        self.fileSizeCache = sizeCache

        await MainActor.run {
            self.progressSubject.send(.partialResult(
                processed: Int(Double(totalCount) * 0.5),
                total: totalCount,
                result: partialResult
            ))
        }

        // --- Videos ---
        var collectedVideos: [PHAsset] = []
        collectedVideos.reserveCapacity(totalVideos)
        let videoBatchSize = 500
        for batchStart in stride(from: 0, to: totalVideos, by: videoBatchSize) {
            if Task.isCancelled { return }
            autoreleasepool {
                let batchEnd = min(batchStart + videoBatchSize, totalVideos)
                for j in batchStart..<batchEnd {
                    let asset = videoFetch.object(at: j)
                    collectedVideos.append(asset)
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let size = resources.first?.value(forKey: "fileSize") as? Int64 {
                        sizeCache[asset.localIdentifier] = size
                    }
                }
            }
        }
        self.videoAssets = collectedVideos
        self.fileSizeCache = sizeCache

        if Task.isCancelled { return }

        // --- Photos (with size caching to avoid disk reads during hashing) ---
        var photoAssets: [PHAsset] = []
        photoAssets.reserveCapacity(totalPhotos)
        let photoBatchSize = 500
        for batchStart in stride(from: 0, to: totalPhotos, by: photoBatchSize) {
            if Task.isCancelled { break }
            autoreleasepool {
                let batchEnd = min(batchStart + photoBatchSize, totalPhotos)
                for j in batchStart..<batchEnd {
                    let asset = photoFetch.object(at: j)
                    photoAssets.append(asset)
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let size = resources.first?.value(forKey: "fileSize") as? Int64 {
                        sizeCache[asset.localIdentifier] = size
                    }
                }
            }
        }
        self.fileSizeCache = sizeCache
        if Task.isCancelled { return }

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

        let photoAssetCount = photoAssets.count
        await MainActor.run {
            self.progressSubject.send(.hashing(processed: 0, total: photoAssetCount))
        }

        let hashes = await hashingService.hashAssets(photoAssets, fileSizeCache: sizeCache) { [weak self] processed, total in
            guard let self else { return }
            Task { @MainActor in
                self.progressSubject.send(.hashing(processed: processed, total: total))
            }
        }

        if Task.isCancelled { return }

        // ═══════════════════════════════════════════════════════════
        // Phase 4: Detect duplicates and similar photos
        // Runs on a detached background task so the UI stays responsive.
        // Publishes .detecting state so progress bar keeps moving.
        // ═══════════════════════════════════════════════════════════

        await MainActor.run {
            self.progressSubject.send(.detecting(processed: 0, total: hashes.count))
        }

        let dupService = self.duplicateDetectionService
        let simService = self.similarDetectionService
        let (detectedDuplicates, detectedSimilar) = await Task.detached(priority: .userInitiated) {
            let duplicates = dupService.findDuplicates(from: hashes)
            let duplicateIds = Set(duplicates.flatMap { $0.photos.map(\.id) })
            let similar = simService.findSimilarGroups(
                from: hashes,
                excludingDuplicateIds: duplicateIds
            )
            return (duplicates, similar)
        }.value

        self.duplicateGroups = detectedDuplicates
        self.similarGroups = detectedSimilar

        let dupPhotoCount = detectedDuplicates.reduce(0) { $0 + $1.count }
        let dupSize = detectedDuplicates.reduce(Int64(0)) { $0 + $1.totalSize }
        let simPhotoCount = detectedSimilar.reduce(0) { $0 + $1.count }
        let simSize = detectedSimilar.reduce(Int64(0)) { $0 + $1.totalSize }

        // ═══════════════════════════════════════════════════════════
        // Phase 5: Final result with everything
        // Use exact file sizes from sizeCache instead of Phase 1 estimates.
        // ═══════════════════════════════════════════════════════════

        let exactTotalSize = sizeCache.values.reduce(Int64(0), +)

        // Compute exact per-category sizes from sizeCache
        let exactScreenshotsSize = collectedScreenshots.reduce(Int64(0)) {
            $0 + (sizeCache[$1.localIdentifier] ?? 0)
        }
        let exactVideosSize = collectedVideos.reduce(Int64(0)) {
            $0 + (sizeCache[$1.localIdentifier] ?? 0)
        }
        let exactPhotosSize = exactTotalSize - exactVideosSize

        let finalResult = ScanResult(
            totalAssets: totalCount,
            totalPhotos: totalPhotos,
            totalVideos: totalVideos,
            totalScreenshots: totalScreenshots,
            totalSizeBytes: exactTotalSize,
            photosSizeBytes: exactPhotosSize,
            videosSizeBytes: exactVideosSize,
            screenshotsSizeBytes: exactScreenshotsSize,
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

    private func estimateTotalSize(fetch: PHFetchResult<PHAsset>, sampleCount: Int) -> Int64 {
        let count = fetch.count
        guard count > 0 else { return 0 }

        // For small collections, measure all items exactly
        if count <= sampleCount * 2 {
            var exactTotal: Int64 = 0
            autoreleasepool {
                for i in 0..<count {
                    let asset = fetch.object(at: i)
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let resource = resources.first,
                       let size = resource.value(forKey: "fileSize") as? Int64 {
                        exactTotal += size
                    }
                }
            }
            return exactTotal
        }

        // For large collections, sample evenly across the entire range
        // (not just first N) to account for size distribution variance
        let actualSampleCount = min(sampleCount, count)
        let step = count / actualSampleCount
        var sampleTotalSize: Int64 = 0

        autoreleasepool {
            for s in 0..<actualSampleCount {
                let idx = min(s * step, count - 1)
                let asset = fetch.object(at: idx)
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
