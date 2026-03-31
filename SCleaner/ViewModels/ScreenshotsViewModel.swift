import SwiftUI
import Photos

/// ViewModel for the screenshots review screen.
@MainActor
final class ScreenshotsViewModel: ObservableObject {
    @Published var assets: [PHAsset]
    @Published var selectedIds: Set<String> = []
    @Published var isDeleting = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false
    @Published var showPaywall = false
    @Published var limitMessage: String?
    @Published var thumbnailVersion: Int = 0

    // Pagination
    private static let pageSize = 100
    @Published var displayedCount: Int = 0

    let thumbnails = ThumbnailStore()
    private var loadingIds: Set<String> = []

    private let thumbnailService: ThumbnailCacheService
    private let deletionService: PhotoDeletionService
    private let limitService = DeletionLimitService.shared

    /// File size cache: pre-computed during scan, passed in from PhotoLibraryService.
    private var fileSizeCache: [String: Int64]

    var totalSelectedCount: Int { selectedIds.count }
    var totalScreenshotCount: Int { assets.count }

    var displayedAssets: [PHAsset] { Array(assets.prefix(displayedCount)) }

    var totalPotentialSavings: Int64 {
        selectedIds.reduce(Int64(0)) { $0 + (fileSizeCache[$1] ?? 0) }
    }

    var totalSize: Int64 {
        assets.reduce(Int64(0)) { $0 + (fileSizeCache[$1.localIdentifier] ?? 0) }
    }

    func fileSize(for asset: PHAsset) -> Int64 {
        fileSizeCache[asset.localIdentifier] ?? 0
    }

    init(
        assets: [PHAsset],
        fileSizeCache: [String: Int64],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        self.fileSizeCache = fileSizeCache
        self.assets = assets
        self.thumbnailService = thumbnailService
        self.deletionService = deletionService
        self.displayedCount = min(Self.pageSize, assets.count)
        self.selectedIds = Set(assets.map(\.localIdentifier))
    }

    func loadNextPageIfNeeded(currentAsset: PHAsset) {
        guard displayedCount < assets.count else { return }
        let threshold = max(0, displayedCount - 20)
        if let index = assets.firstIndex(where: { $0.localIdentifier == currentAsset.localIdentifier }),
           index >= threshold {
            displayedCount = min(displayedCount + Self.pageSize, assets.count)
        }
    }

    func toggleSelection(assetId: String) {
        if selectedIds.contains(assetId) { selectedIds.remove(assetId) }
        else { selectedIds.insert(assetId) }
    }

    func selectAll() { for asset in assets { selectedIds.insert(asset.localIdentifier) } }
    func deselectAll() { selectedIds.removeAll() }

    func loadThumbnails(for visibleAssets: [PHAsset]) {
        let targetSize = AppConstants.Storage.thumbnailSize
        for asset in visibleAssets {
            let id = asset.localIdentifier
            guard !thumbnails.contains(id), !loadingIds.contains(id) else { continue }
            loadingIds.insert(id)
            Task {
                if let image = await thumbnailService.loadThumbnail(for: asset, targetSize: targetSize) {
                    thumbnails[id] = image
                    thumbnailVersion += 1
                }
                loadingIds.remove(id)
            }
        }
    }

    func evictThumbnails(for assetIds: [String]) {
        for id in assetIds { thumbnails.remove(id) }
    }

    func confirmDeletion() {
        limitMessage = nil
        if !limitService.canDelete(count: totalSelectedCount) {
            if limitService.isLimitReached { showPaywall = true }
            else {
                let remaining = limitService.remainingDeletions
                limitMessage = String(format: NSLocalizedString("general.limitMessage", comment: ""), remaining)
            }
            return
        }
        showDeleteConfirmation = true
    }

    func executeDelete() async {
        let allowed = limitService.allowedCount(requested: totalSelectedCount)
        if allowed <= 0 && !SubscriptionService.shared.isPremium { showPaywall = true; return }

        isDeleting = true
        let idsToDelete = Array(selectedIds.prefix(allowed))

        do {
            let result = try await deletionService.deletePhotos(assetIds: idsToDelete)
            deleteResult = result
            assets = assets.filter { !result.deletedAssetIds.contains($0.localIdentifier) }
            for id in result.deletedAssetIds {
                selectedIds.remove(id)
                fileSizeCache.removeValue(forKey: id)
            }
            displayedCount = min(displayedCount, assets.count)
            limitService.recordDeletions(count: result.deletedCount)
            showDeleteSuccess = true
            NotificationCenter.default.post(name: DashboardViewModel.photosDeletedNotification, object: nil)
        } catch { }

        isDeleting = false
    }
}
