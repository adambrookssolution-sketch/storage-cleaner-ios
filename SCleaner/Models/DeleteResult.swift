import Foundation

/// Result of a batch deletion operation
struct DeleteResult: Equatable {
    let requestedCount: Int
    let deletedCount: Int
    let failedCount: Int
    let deletedAssetIds: Set<String>
    let savedBytes: Int64

    var isFullSuccess: Bool { failedCount == 0 }
    var isPartialSuccess: Bool { deletedCount > 0 && failedCount > 0 }

    static let empty = DeleteResult(
        requestedCount: 0,
        deletedCount: 0,
        failedCount: 0,
        deletedAssetIds: [],
        savedBytes: 0
    )
}
