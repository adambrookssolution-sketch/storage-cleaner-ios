import Foundation

/// Protocol for storage analysis, enabling mock injection
protocol StorageServicing {
    /// Returns device storage information
    func getDeviceStorageInfo() -> StorageInfo

    /// Calculates the total size of the photo library
    func getPhotoLibrarySize() async -> Int64
}
