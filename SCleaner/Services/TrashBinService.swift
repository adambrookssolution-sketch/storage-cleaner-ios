import Foundation
import Combine

/// Manages the app-internal trash bin at Documents/TrashBin/.
/// Files moved to trash are copied here with metadata in manifest.json.
/// Auto-purges files older than 30 days.
final class TrashBinService: ObservableObject {

    static let shared = TrashBinService()

    @Published private(set) var manifest: TrashBinManifest = .empty

    private let fileManager = FileManager.default
    private let trashBinURL: URL

    private static func resolveTrashBinURL(fileManager: FileManager) -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback: construct from HOME if the standard API returns empty (should never happen on iOS)
            let fallback = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            return fallback.appendingPathComponent(AppConstants.TrashBin.directoryName, isDirectory: true)
        }
        return docs.appendingPathComponent(AppConstants.TrashBin.directoryName, isDirectory: true)
    }

    private var manifestURL: URL {
        trashBinURL.appendingPathComponent(AppConstants.TrashBin.manifestFileName)
    }

    init() {
        trashBinURL = Self.resolveTrashBinURL(fileManager: fileManager)
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
            // 1. Copy file to trash directory
            try fileManager.copyItem(at: file.fileURL, to: destinationURL)

            // 2. Save manifest BEFORE deleting original (crash-safe: worst case = duplicate, not data loss)
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

            // 3. Delete original file
            try fileManager.removeItem(at: file.fileURL)

            return true
        } catch {
            // Clean up: if copy succeeded but delete failed, remove the copy and revert manifest
            if fileManager.fileExists(atPath: destinationURL.path),
               fileManager.fileExists(atPath: file.fileURL.path) {
                try? fileManager.removeItem(at: destinationURL)
                manifest.files.removeAll { $0.id == trashedId }
                saveManifest()
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
