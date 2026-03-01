import Foundation

/// Handles deletion of files from the user's Downloads folder
/// by moving them to the internal trash bin.
final class FileDeletionService {

    private let trashBinService: TrashBinService

    init(trashBinService: TrashBinService = .shared) {
        self.trashBinService = trashBinService
    }

    func deleteFiles(files: [DownloadedFile], folderBookmark: Data?) -> DeleteResult {
        var deletedCount = 0
        var failedCount = 0
        var savedBytes: Int64 = 0
        var deletedIds = Set<String>()

        for file in files {
            if trashBinService.moveToTrash(file: file, folderBookmark: folderBookmark) {
                deletedCount += 1
                savedBytes += file.fileSize
                deletedIds.insert(file.id)
            } else {
                failedCount += 1
            }
        }

        return DeleteResult(
            requestedCount: files.count,
            deletedCount: deletedCount,
            failedCount: failedCount,
            deletedAssetIds: deletedIds,
            savedBytes: savedBytes
        )
    }
}
