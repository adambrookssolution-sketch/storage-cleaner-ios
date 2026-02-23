import SwiftUI
import Photos

/// ViewModel for the videos review screen.
/// Manages a flat list of video assets sorted by size, with selection and deletion.
@MainActor
final class VideosViewModel: ObservableObject {
    @Published var assets: [PHAsset]
    @Published var selectedIds: Set<String> = []
    @Published var thumbnailCache: [String: UIImage] = [:]
    @Published var isDeleting = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false

    private let thumbnailService: ThumbnailCacheService
    private let deletionService: PhotoDeletionService

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
        self.assets = assets
        self.thumbnailService = thumbnailService
        self.deletionService = deletionService
    }

    func toggleSelection(assetId: String) {
        if selectedIds.contains(assetId) {
            selectedIds.remove(assetId)
        } else {
            selectedIds.insert(assetId)
        }
    }

    func selectAll() {
        for asset in assets {
            selectedIds.insert(asset.localIdentifier)
        }
    }

    func deselectAll() {
        selectedIds.removeAll()
    }

    func loadThumbnails(for visibleAssets: [PHAsset]) {
        let targetSize = AppConstants.Storage.thumbnailSize
        for asset in visibleAssets {
            let id = asset.localIdentifier
            guard thumbnailCache[id] == nil else { continue }
            Task {
                if let image = await thumbnailService.loadThumbnail(
                    assetId: id, targetSize: targetSize
                ) {
                    thumbnailCache[id] = image
                }
            }
        }
    }

    func executeDelete() async {
        isDeleting = true
        let idsToDelete = Array(selectedIds)

        do {
            let result = try await deletionService.deletePhotos(assetIds: idsToDelete)
            deleteResult = result
            assets = assets.filter { !result.deletedAssetIds.contains($0.localIdentifier) }
            for id in result.deletedAssetIds {
                selectedIds.remove(id)
            }
            showDeleteSuccess = true
            NotificationCenter.default.post(
                name: DashboardViewModel.photosDeletedNotification, object: nil
            )
        } catch {
            // User cancelled or error
        }

        isDeleting = false
    }
}
