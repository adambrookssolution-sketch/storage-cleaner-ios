import Foundation

/// Persisted manifest tracking all files in the internal trash bin.
struct TrashBinManifest: Codable {
    var files: [TrashedFile]
    var lastPurgeDate: Date?

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.fileSize }
    }

    var totalCount: Int { files.count }

    var expiredFiles: [TrashedFile] {
        files.filter { $0.isExpired }
    }

    static let empty = TrashBinManifest(files: [], lastPurgeDate: nil)
}
