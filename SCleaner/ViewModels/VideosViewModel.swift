import SwiftUI
import Photos

/// ViewModel for the videos review screen.
@MainActor
final class VideosViewModel: ObservableObject {
    @Published var assets: [PHAsset]
    @Published var selectedIds: Set<String> = []
    @Published var isDeleting = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false
    @Published var showPaywall = false
    @Published var limitMessage: String?
    @Published var thumbnailVersion: Int = 0

    let thumbnails = ThumbnailStore()
    private var loadingIds: Set<String> = []

    private let thumbnailService: ThumbnailCacheService
    private let deletionService: PhotoDeletionService
    private let limitService = DeletionLimitService.shared

    var totalSelectedCount: Int { selectedIds.count }
    var totalVideoCount: Int { assets.count }

    var totalPotentialSavings: Int64 {
        assets.filter { selectedIds.contains($0.localIdentifier) }
            .reduce(Int64(0)) { $0 + $1.estimatedFileSize }
    }

    var totalSize: Int64 {
        assets.reduce(Int64(0)) { $0 + $1.estimatedFileSize }
    }

    init(
        assets: [PHAsset],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        self.assets = assets.sorted { $0.estimatedFileSize > $1.estimatedFileSize }
        self.thumbnailService = thumbnailService
        self.deletionService = deletionService
        let topHeaviest = self.assets.prefix(15)
        self.selectedIds = Set(topHeaviest.map(\.localIdentifier))
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
            else { limitMessage = String(format: NSLocalizedString("general.limitMessage", comment: ""), limitService.remainingDeletions) }
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
            for id in result.deletedAssetIds { selectedIds.remove(id) }
            limitService.recordDeletions(count: result.deletedCount)
            showDeleteSuccess = true
            NotificationCenter.default.post(name: DashboardViewModel.photosDeletedNotification, object: nil)
        } catch { }

        isDeleting = false
    }
}
