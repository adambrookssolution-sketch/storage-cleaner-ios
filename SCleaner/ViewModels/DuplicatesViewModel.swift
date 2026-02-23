import SwiftUI
import Photos

/// ViewModel for the duplicates detail screen.
/// Manages group data, selection state, thumbnail loading, and deletion.
@MainActor
final class DuplicatesViewModel: ObservableObject {
    // MARK: - Published State
    @Published var groups: [DuplicateGroup]
    @Published var selectedIds: Set<String> = []
    @Published var thumbnailCache: [String: UIImage] = [:]
    @Published var isDeleting = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false

    // MARK: - Dependencies
    private let thumbnailService: ThumbnailCacheService
    private let deletionService: PhotoDeletionService

    // MARK: - Computed
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

    // MARK: - Init

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

    // MARK: - Selection

    /// Auto-selects all photos except the "best result" in each group
    func autoSelectDuplicates() {
        selectedIds.removeAll()
        for group in groups {
            for (index, photo) in group.photos.enumerated() {
                if index != group.bestResultIndex {
                    selectedIds.insert(photo.id)
                }
            }
        }
    }

    func toggleSelection(assetId: String) {
        if selectedIds.contains(assetId) {
            selectedIds.remove(assetId)
        } else {
            selectedIds.insert(assetId)
        }
    }

    func selectAllInGroup(_ group: DuplicateGroup) {
        for (index, photo) in group.photos.enumerated() {
            if index != group.bestResultIndex {
                selectedIds.insert(photo.id)
            }
        }
    }

    func deselectAllInGroup(_ group: DuplicateGroup) {
        for photo in group.photos {
            selectedIds.remove(photo.id)
        }
    }

    func isSelected(_ assetId: String) -> Bool {
        selectedIds.contains(assetId)
    }

    // MARK: - Thumbnails

    func loadThumbnails(for group: DuplicateGroup) {
        let targetSize = AppConstants.Storage.thumbnailSize
        for photo in group.photos {
            guard thumbnailCache[photo.id] == nil else { continue }
            Task {
                if let image = await thumbnailService.loadThumbnail(
                    assetId: photo.id, targetSize: targetSize
                ) {
                    thumbnailCache[photo.id] = image
                }
            }
        }
    }

    // MARK: - Deletion

    func confirmDeletion() {
        showDeleteConfirmation = true
    }

    func executeDelete() async {
        isDeleting = true
        let idsToDelete = Array(selectedIds)

        do {
            let result = try await deletionService.deletePhotos(assetIds: idsToDelete)
            deleteResult = result

            // Remove deleted photos from groups
            groups = groups.compactMap { group in
                let remainingPhotos = group.photos.filter {
                    !result.deletedAssetIds.contains($0.id)
                }
                if remainingPhotos.count < 2 { return nil }
                let bestIndex = DuplicateDetectionService()
                    .selectBestResult(from: remainingPhotos)
                return DuplicateGroup(
                    id: group.id,
                    photos: remainingPhotos,
                    bestResultIndex: bestIndex
                )
            }

            // Clear deleted from selection
            for id in result.deletedAssetIds {
                selectedIds.remove(id)
            }

            showDeleteSuccess = true

            // Notify dashboard to rescan
            NotificationCenter.default.post(name: DashboardViewModel.photosDeletedNotification, object: nil)
        } catch {
            // User cancelled or error occurred
        }

        isDeleting = false
    }
}
