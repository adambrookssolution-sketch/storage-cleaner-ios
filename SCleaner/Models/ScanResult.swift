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

    /// Category count/size pairs for dashboard display
    /// In M1, duplicates/similar counts are zero (detection comes in M2)
    var categoryCounts: [MediaCategory: (count: Int, sizeBytes: Int64)] {
        var result: [MediaCategory: (Int, Int64)] = [:]
        result[.screenshots] = (totalScreenshots, screenshotsSizeBytes)
        result[.videos] = (totalVideos, videosSizeBytes)
        // M1 placeholders — detection logic comes in M2
        result[.duplicates] = (0, 0)
        result[.similar] = (0, 0)
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

    static let empty = ScanResult(
        totalAssets: 0,
        totalPhotos: 0,
        totalVideos: 0,
        totalScreenshots: 0,
        totalSizeBytes: 0,
        photosSizeBytes: 0,
        videosSizeBytes: 0,
        screenshotsSizeBytes: 0
    )
}
