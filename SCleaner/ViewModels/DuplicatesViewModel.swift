import SwiftUI
import Photos

/// ViewModel for the duplicates detail screen.
@MainActor
final class DuplicatesViewModel: ObservableObject {
    @Published var groups: [DuplicateGroup]
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
    var totalPotentialSavings: Int64 {
        var total: Int64 = 0
        for group in groups {
            for photo in group.photos where selectedIds.contains(photo.id) {
                total += photo.fileSize
            }
        }
        return total
    }
    var totalGroupCount: Int { groups.count }
    var totalDuplicateCount: Int { groups.reduce(0) { $0 + $1.count } }

    init(
        groups: [DuplicateGroup],
        thumbnailService: ThumbnailCacheService,
        deletionService: PhotoDeletionService
    ) {
        self.groups = groups
        self.thumbnailService = thumbnailService
        self.deletionService = deletionService
        autoSelectDuplicates()
    }

    func autoSelectDuplicates() {
        selectedIds.removeAll()
        for group in groups {
            for (index, photo) in group.photos.enumerated() {
                if index != group.bestResultIndex { selectedIds.insert(photo.id) }
            }
        }
    }

    func toggleSelection(assetId: String) {
        if selectedIds.contains(assetId) { selectedIds.remove(assetId) }
        else { selectedIds.insert(assetId) }
    }

    func selectAllInGroup(_ group: DuplicateGroup) {
        for (index, photo) in group.photos.enumerated() {
            if index != group.bestResultIndex { selectedIds.insert(photo.id) }
        }
    }

    func deselectAllInGroup(_ group: DuplicateGroup) {
        for photo in group.photos { selectedIds.remove(photo.id) }
    }

    func isSelected(_ assetId: String) -> Bool { selectedIds.contains(assetId) }

    func loadThumbnails(for group: DuplicateGroup) {
        let targetSize = AppConstants.Storage.thumbnailSize
        for photo in group.photos {
            guard !thumbnails.contains(photo.id), !loadingIds.contains(photo.id) else { continue }
            loadingIds.insert(photo.id)
            Task {
                if let image = await thumbnailService.loadThumbnail(assetId: photo.id, targetSize: targetSize) {
                    thumbnails[photo.id] = image
                    thumbnailVersion += 1
                }
                loadingIds.remove(photo.id)
            }
        }
    }

    func evictThumbnails(for ids: [String]) {
        for id in ids { thumbnails.remove(id) }
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
            groups = groups.compactMap { group in
                let remaining = group.photos.filter { !result.deletedAssetIds.contains($0.id) }
                if remaining.count < 2 { return nil }
                let bestIndex = DuplicateDetectionService().selectBestResult(from: remaining)
                return DuplicateGroup(id: group.id, photos: remaining, bestResultIndex: bestIndex)
            }
            for id in result.deletedAssetIds { selectedIds.remove(id) }
            limitService.recordDeletions(count: result.deletedCount)
            showDeleteSuccess = true
            NotificationCenter.default.post(name: DashboardViewModel.photosDeletedNotification, object: nil)
        } catch { }

        isDeleting = false
    }
}
