import Foundation
import Combine

/// Manages the app-internal trash bin at Documents/TrashBin/.
/// Files moved to trash are copied here with metadata in manifest.json.
/// Auto-purges files older than 30 days.
final class TrashBinService: ObservableObject {

    static let shared = TrashBinService()

    @Published private(set) var manifest: TrashBinManifest = .empty

    private let fileManager = FileManager.default

    private var trashBinURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(AppConstants.TrashBin.directoryName, isDirectory: true)
    }

    private var manifestURL: URL {
        trashBinURL.appendingPathComponent(AppConstants.TrashBin.manifestFileName)
    }

    init() {
        ensureDirectoryExists()
        loadManifest()
        purgeExpiredFiles()
    }

    // MARK: - Directory

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: trashBinURL.path) {
            try? fileManager.createDirectory(at: trashBinURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Manifest

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode(TrashBinManifest.self, from: data)
        else {
            manifest = .empty
            return
        }
        manifest = decoded
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Move to Trash

    func moveToTrash(file: DownloadedFile, folderBookmark: Data?) -> Bool {
        let trashedId = UUID().uuidString
        let ext = file.fileExtension
        let storedName = ext.isEmpty ? trashedId : "\(trashedId).\(ext)"
        let destinationURL = trashBinURL.appendingPathComponent(storedName)

        do {
            try fileManager.copyItem(at: file.fileURL, to: destinationURL)
            try fileManager.removeItem(at: file.fileURL)

            let trashedFile = TrashedFile(
                id: trashedId,
                originalFileName: file.fileName,
                originalFolderBookmark: folderBookmark,
                originalRelativePath: file.fileName,
                fileSize: file.fileSize,
                deletionDate: Date(),
                fileType: file.fileType.rawValue
            )

            manifest.files.append(trashedFile)
            saveManifest()
            return true
        } catch {
            // Clean up partial copy if the delete failed
            if fileManager.fileExists(atPath: destinationURL.path),
               fileManager.fileExists(atPath: file.fileURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            return false
        }
    }

    // MARK: - Restore

    func restoreFromTrash(trashedFile: TrashedFile) -> Bool {
        let storedName = trashedFile.storedFileName
        let sourceURL = trashBinURL.appendingPathComponent(storedName)

        guard fileManager.fileExists(atPath: sourceURL.path) else { return false }
        guard let bookmarkData = trashedFile.originalFolderBookmark else { return false }

        var isStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            bookmarkDataIsStale: &isStale
        ) else { return false }

        guard folderURL.startAccessingSecurityScopedResource() else { return false }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let destinationURL = folderURL.appendingPathComponent(trashedFile.originalRelativePath)

        do {
            var finalURL = destinationURL
            if fileManager.fileExists(atPath: finalURL.path) {
                let stem = (trashedFile.originalFileName as NSString).deletingPathExtension
                let ext = (trashedFile.originalFileName as NSString).pathExtension
                let timestamp = Int(Date().timeIntervalSince1970)
                let newName = ext.isEmpty ? "\(stem)_restored_\(timestamp)" : "\(stem)_restored_\(timestamp).\(ext)"
                finalURL = folderURL.appendingPathComponent(newName)
            }

            try fileManager.copyItem(at: sourceURL, to: finalURL)
            try fileManager.removeItem(at: sourceURL)

            manifest.files.removeAll { $0.id == trashedFile.id }
            saveManifest()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Permanent Delete

    func permanentlyDelete(trashedFile: TrashedFile) -> Bool {
        let storedName = trashedFile.storedFileName
        let fileURL = trashBinURL.appendingPathComponent(storedName)

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            manifest.files.removeAll { $0.id == trashedFile.id }
            saveManifest()
            return true
        } catch {
            return false
        }
    }

    func permanentlyDeleteMultiple(ids: Set<String>) -> DeleteResult {
        var deletedCount = 0
        var failedCount = 0
        var savedBytes: Int64 = 0
        var deletedIds = Set<String>()

        let filesToDelete = manifest.files.filter { ids.contains($0.id) }
        for file in filesToDelete {
            let storedName = file.storedFileName
            let fileURL = trashBinURL.appendingPathComponent(storedName)
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                deletedCount += 1
                savedBytes += file.fileSize
                deletedIds.insert(file.id)
            } catch {
                failedCount += 1
            }
        }

        manifest.files.removeAll { deletedIds.contains($0.id) }
        saveManifest()

        return DeleteResult(
            requestedCount: ids.count,
            deletedCount: deletedCount,
            failedCount: failedCount,
            deletedAssetIds: deletedIds,
            savedBytes: savedBytes
        )
    }

    // MARK: - Auto-Purge

    func purgeExpiredFiles() {
        let expired = manifest.expiredFiles
        guard !expired.isEmpty else { return }

        for file in expired {
            let storedName = file.storedFileName
            let fileURL = trashBinURL.appendingPathComponent(storedName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
        manifest.files.removeAll { $0.isExpired }
        manifest.lastPurgeDate = Date()
        saveManifest()
    }

    // MARK: - Stats

    var totalTrashSize: Int64 { manifest.totalSize }
    var totalTrashCount: Int { manifest.totalCount }

    func refresh() {
        loadManifest()
    }
}
