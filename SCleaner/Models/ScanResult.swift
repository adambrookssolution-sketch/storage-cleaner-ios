import Foundation

/// Output model from a completed library scan
struct ScanResult: Equatable {
    let totalAssets: Int
    let totalPhotos: Int
    let totalVideos: Int
    let totalScreenshots: Int
    let totalSizeBytes: Int64
    let photosSizeBytes: Int64
    let videosSizeBytes: Int64
    let screenshotsSizeBytes: Int64

    // M2: Duplicate and similar detection results
    let duplicateGroupCount: Int
    let duplicatePhotoCount: Int
    let duplicateSizeBytes: Int64
    let similarGroupCount: Int
    let similarPhotoCount: Int
    let similarSizeBytes: Int64

    /// Category count/size pairs for dashboard display
    var categoryCounts: [MediaCategory: (count: Int, sizeBytes: Int64)] {
        var result: [MediaCategory: (Int, Int64)] = [:]
        result[.screenshots] = (totalScreenshots, screenshotsSizeBytes)
        result[.videos] = (totalVideos, videosSizeBytes)
        // M2: Real duplicate/similar data
        result[.duplicates] = (duplicatePhotoCount, duplicateSizeBytes)
        result[.similar] = (similarPhotoCount, similarSizeBytes)
        result[.similarVideos] = (0, 0)
        result[.similarScreenshots] = (0, 0)
        let otherPhotos = max(0, totalPhotos - totalScreenshots)
        let otherSize = max(0, photosSizeBytes - screenshotsSizeBytes)
        result[.other] = (otherPhotos, otherSize)
        return result
    }

    var formattedTotalSize: String {
        totalSizeBytes.formattedSize
    }

    // Compare only scalar fields (exclude large arrays from equality)
    static func == (lhs: ScanResult, rhs: ScanResult) -> Bool {
        lhs.totalAssets == rhs.totalAssets &&
        lhs.totalPhotos == rhs.totalPhotos &&
        lhs.totalVideos == rhs.totalVideos &&
        lhs.totalScreenshots == rhs.totalScreenshots &&
        lhs.totalSizeBytes == rhs.totalSizeBytes &&
        lhs.duplicateGroupCount == rhs.duplicateGroupCount &&
        lhs.similarGroupCount == rhs.similarGroupCount
    }

    static let empty = ScanResult(
        totalAssets: 0,
        totalPhotos: 0,
        totalVideos: 0,
        totalScreenshots: 0,
        totalSizeBytes: 0,
        photosSizeBytes: 0,
        videosSizeBytes: 0,
        screenshotsSizeBytes: 0,
        duplicateGroupCount: 0,
        duplicatePhotoCount: 0,
        duplicateSizeBytes: 0,
        similarGroupCount: 0,
        similarPhotoCount: 0,
        similarSizeBytes: 0
    )
}
