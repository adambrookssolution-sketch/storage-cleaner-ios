import Photos

/// Queries device-level storage information
final class StorageAnalysisService: StorageServicing {

    func getDeviceStorageInfo() -> StorageInfo {
        let (total, available, used) = FileManager.deviceStorageInfo()
        return StorageInfo(
            totalBytes: total,
            usedBytes: used,
            availableBytes: available,
            photoLibraryBytes: 0 // filled separately by async call
        )
    }

    /// Creates a StorageInfo with the photo library size included
    func getDeviceStorageInfoWithPhotos(photoLibrarySize: Int64) -> StorageInfo {
        let (total, available, used) = FileManager.deviceStorageInfo()
        return StorageInfo(
            totalBytes: total,
            usedBytes: used,
            availableBytes: available,
            photoLibraryBytes: photoLibrarySize
        )
    }

    /// Iterates all PHAssets and sums file sizes. Run on background thread.
    func getPhotoLibrarySize() async -> Int64 {
        return await withCheckedContinuation { continuation in
            var totalSize: Int64 = 0
            let fetchOptions = PHFetchOptions()
            let allAssets = PHAsset.fetchAssets(with: fetchOptions)
            allAssets.enumerateObjects { asset, _, _ in
                totalSize += asset.estimatedFileSize
            }
            continuation.resume(returning: totalSize)
        }
    }
}
