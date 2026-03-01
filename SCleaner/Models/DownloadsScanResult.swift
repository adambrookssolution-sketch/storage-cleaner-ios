import Foundation

/// Result of scanning the user's selected Downloads folder.
struct DownloadsScanResult: Equatable {
    let totalFiles: Int
    let totalSizeBytes: Int64
    let filteredFiles: [DownloadedFile]
    let filteredSizeBytes: Int64
    let allFiles: [DownloadedFile]
    let folderName: String

    static let empty = DownloadsScanResult(
        totalFiles: 0,
        totalSizeBytes: 0,
        filteredFiles: [],
        filteredSizeBytes: 0,
        allFiles: [],
        folderName: ""
    )
}
