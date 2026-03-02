import SwiftUI

/// ViewModel for the Trash Bin management screen.
@MainActor
final class TrashBinViewModel: ObservableObject {
    // MARK: - Published State
    @Published var trashedFiles: [TrashedFile] = []
    @Published var selectedIds: Set<String> = []
    @Published var isProcessing = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false
    @Published var showRestoreConfirmation = false
    @Published var restoreResult: (success: Int, failed: Int)?
    @Published var showRestoreSuccess = false
    @Published var errorMessage: String?

    private let trashBinService: TrashBinService

    // MARK: - Computed
    var totalSelectedCount: Int { selectedIds.count }
    var totalCount: Int { trashedFiles.count }

    var totalSize: Int64 {
        trashedFiles.reduce(Int64(0)) { $0 + $1.fileSize }
    }

    var totalPotentialSavings: Int64 {
        trashedFiles.filter { selectedIds.contains($0.id) }
            .reduce(Int64(0)) { $0 + $1.fileSize }
    }

    // MARK: - Init
    init(trashBinService: TrashBinService = .shared) {
        self.trashBinService = trashBinService
        self.trashedFiles = trashBinService.manifest.files
    }

    // MARK: - Actions

    func refresh() {
        trashBinService.refresh()
        trashedFiles = trashBinService.manifest.files
    }

    func toggleSelection(fileId: String) {
        if selectedIds.contains(fileId) {
            selectedIds.remove(fileId)
        } else {
            selectedIds.insert(fileId)
        }
    }

    func selectAll() {
        for file in trashedFiles { selectedIds.insert(file.id) }
    }

    func deselectAll() {
        selectedIds.removeAll()
    }

    func executePermanentDelete() async {
        isProcessing = true

        let ids = selectedIds
        let service = trashBinService
        let result = await Task.detached { service.permanentlyDeleteMultiple(ids: ids) }.value

        deleteResult = result
        trashedFiles = trashBinService.manifest.files
        selectedIds.removeAll()
        showDeleteSuccess = true
        isProcessing = false

        NotificationCenter.default.post(
            name: Notification.Name("SCleanerTrashUpdated"),
            object: nil
        )
    }

    func executeRestore() async {
        isProcessing = true
        var successCount = 0
        var failCount = 0

        let filesToRestore = trashedFiles.filter { selectedIds.contains($0.id) }
        let service = trashBinService

        for file in filesToRestore {
            let ok = await Task.detached { service.restoreFromTrash(trashedFile: file) }.value
            if ok {
                successCount += 1
            } else {
                failCount += 1
            }
        }

        restoreResult = (success: successCount, failed: failCount)
        trashedFiles = trashBinService.manifest.files
        selectedIds.removeAll()
        showRestoreSuccess = true
        isProcessing = false

        NotificationCenter.default.post(
            name: Notification.Name("SCleanerTrashUpdated"),
            object: nil
        )
    }

    func emptyTrash() async {
        isProcessing = true
        let allIds = Set(trashedFiles.map(\.id))
        let service = trashBinService
        let result = await Task.detached { service.permanentlyDeleteMultiple(ids: allIds) }.value

        deleteResult = result
        trashedFiles = []
        selectedIds.removeAll()
        showDeleteSuccess = true
        isProcessing = false

        NotificationCenter.default.post(
            name: Notification.Name("SCleanerTrashUpdated"),
            object: nil
        )
    }
}
