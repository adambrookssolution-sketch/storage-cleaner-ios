import SwiftUI

/// ViewModel for the Downloads file scanning and deletion screen.
@MainActor
final class DownloadsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var allFiles: [DownloadedFile] = []
    @Published var filteredFiles: [DownloadedFile] = []
    @Published var selectedIds: Set<String> = []
    @Published var isScanning = false
    @Published var scanResult: DownloadsScanResult = .empty
    @Published var isDeleting = false
    @Published var deleteResult: DeleteResult?
    @Published var showDeleteConfirmation = false
    @Published var showDeleteSuccess = false
    @Published var showPaywall = false
    @Published var limitMessage: String?
    @Published var showFolderPicker = false
    @Published var showFilterOnly = true
    @Published var hasFolder = false
    @Published var folderName = ""
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let scanService: DownloadsScanService
    private let deletionService: FileDeletionService
    private let limitService = DeletionLimitService.shared
    private var folderBookmark: Data?
    private var folderURL: URL?

    // MARK: - Computed
    var displayedFiles: [DownloadedFile] {
        showFilterOnly ? filteredFiles : allFiles
    }

    var totalSelectedCount: Int { selectedIds.count }

    var totalPotentialSavings: Int64 {
        displayedFiles.filter { selectedIds.contains($0.id) }
            .reduce(Int64(0)) { $0 + $1.fileSize }
    }

    var totalDisplayedSize: Int64 {
        displayedFiles.reduce(Int64(0)) { $0 + $1.fileSize }
    }

    var totalDisplayedCount: Int { displayedFiles.count }

    // MARK: - Init
    init(
        scanService: DownloadsScanService = DownloadsScanService(),
        deletionService: FileDeletionService = FileDeletionService()
    ) {
        self.scanService = scanService
        self.deletionService = deletionService

        if let url = scanService.resolveBookmark() {
            self.hasFolder = true
            self.folderName = url.lastPathComponent
            self.folderURL = url
        }
    }

    // MARK: - Actions

    func onFolderSelected(url: URL) {
        do {
            try scanService.saveBookmark(for: url)
            self.folderURL = url
            self.hasFolder = true
            self.folderName = url.lastPathComponent
            // Store bookmark immediately so it's available for deletion/restore
            if let bookmarkData = UserDefaults.standard.data(forKey: AppConstants.Downloads.bookmarkKey) {
                self.folderBookmark = bookmarkData
            }
            Task { await scanFolder() }
        } catch {
            errorMessage = "Não foi possível salvar o acesso à pasta."
        }
    }

    func scanFolder() async {
        guard let url = folderURL else {
            showFolderPicker = true
            return
        }

        isScanning = true
        errorMessage = nil

        let result = await scanService.scanFolder(at: url)

        scanResult = result
        allFiles = result.allFiles
        filteredFiles = result.filteredFiles
        folderName = result.folderName
        isScanning = false

        if let bookmarkData = UserDefaults.standard.data(forKey: AppConstants.Downloads.bookmarkKey) {
            self.folderBookmark = bookmarkData
        }
    }

    func selectFolder() {
        showFolderPicker = true
    }

    func changeFolder() {
        scanService.clearBookmark()
        hasFolder = false
        folderURL = nil
        allFiles = []
        filteredFiles = []
        scanResult = .empty
        selectedIds = []
        showFolderPicker = true
    }

    func toggleSelection(fileId: String) {
        if selectedIds.contains(fileId) {
            selectedIds.remove(fileId)
        } else {
            selectedIds.insert(fileId)
        }
    }

    func selectAll() {
        for file in displayedFiles {
            selectedIds.insert(file.id)
        }
    }

    func deselectAll() {
        selectedIds.removeAll()
    }

    func confirmDeletion() {
        limitMessage = nil
        if !limitService.canDelete(count: totalSelectedCount) {
            if limitService.isLimitReached {
                showPaywall = true
            } else {
                let remaining = limitService.remainingDeletions
                limitMessage = "Limite diario: \(remaining) exclusoes restantes. Selecione menos itens ou assine o Premium."
            }
            return
        }
        showDeleteConfirmation = true
    }

    func executeDelete() async {
        let allowed = limitService.allowedCount(requested: totalSelectedCount)
        if allowed <= 0 && !SubscriptionService.shared.isPremium {
            showPaywall = true
            return
        }

        isDeleting = true

        let filesToDelete = Array(displayedFiles.filter { selectedIds.contains($0.id) }.prefix(allowed))

        guard let url = folderURL else {
            isDeleting = false
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Não foi possível acessar a pasta. Selecione novamente."
            isDeleting = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let result = deletionService.deleteFiles(
            files: filesToDelete,
            folderBookmark: folderBookmark
        )

        deleteResult = result

        allFiles = allFiles.filter { !result.deletedAssetIds.contains($0.id) }
        filteredFiles = filteredFiles.filter { !result.deletedAssetIds.contains($0.id) }
        for id in result.deletedAssetIds {
            selectedIds.remove(id)
        }

        limitService.recordDeletions(count: result.deletedCount)
        showDeleteSuccess = true
        isDeleting = false

        NotificationCenter.default.post(
            name: Notification.Name("SCleanerTrashUpdated"),
            object: nil
        )
    }

    func toggleFilter() {
        showFilterOnly.toggle()
        selectedIds.removeAll()
    }
}
