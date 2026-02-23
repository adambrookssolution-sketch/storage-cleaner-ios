import Photos

/// Handles batch deletion of PHAssets via the system Photos framework.
/// Deletions move photos to "Recently Deleted" (30-day recovery).
final class PhotoDeletionService {

    /// Deletes photos by their local identifiers.
    /// iOS will present its own confirmation UI to the user.
    func deletePhotos(assetIds: [String]) async throws -> DeleteResult {
        guard !assetIds.isEmpty else { return .empty }

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds,
            options: nil
        )

        var assetsToDelete: [PHAsset] = []
        var sizeToSave: Int64 = 0
        fetchResult.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
            sizeToSave += asset.estimatedFileSize
        }

        guard !assetsToDelete.isEmpty else {
            return DeleteResult(
                requestedCount: assetIds.count,
                deletedCount: 0,
                failedCount: assetIds.count,
                deletedAssetIds: [],
                savedBytes: 0
            )
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        }

        let deletedIds = Set(assetsToDelete.map(\.localIdentifier))
        return DeleteResult(
            requestedCount: assetIds.count,
            deletedCount: assetsToDelete.count,
            failedCount: assetIds.count - assetsToDelete.count,
            deletedAssetIds: deletedIds,
            savedBytes: sizeToSave
        )
    }
}
