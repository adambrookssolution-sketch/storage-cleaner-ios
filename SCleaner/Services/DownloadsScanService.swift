import Foundation

/// Scans a user-selected folder via security-scoped URLs and enumerates files.
final class DownloadsScanService {

    // MARK: - Bookmark Management

    func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: AppConstants.Downloads.bookmarkKey)
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.Downloads.bookmarkKey) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            if url.startAccessingSecurityScopedResource() {
                try? saveBookmark(for: url)
                url.stopAccessingSecurityScopedResource()
            }
        }
        return url
    }

    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: AppConstants.Downloads.bookmarkKey)
    }

    var hasStoredBookmark: Bool {
        UserDefaults.standard.data(forKey: AppConstants.Downloads.bookmarkKey) != nil
    }

    // MARK: - Scanning

    func scanFolder(at folderURL: URL) async -> DownloadsScanResult {
        guard folderURL.startAccessingSecurityScopedResource() else {
            return .empty
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isRegularFileKey,
            .nameKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return .empty
        }

        var allFiles: [DownloadedFile] = []

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.isRegularFile == true else { continue }

            let fileName = values.name ?? fileURL.lastPathComponent
            let ext = fileURL.pathExtension
            let fileSize = Int64(values.fileSize ?? 0)
            let modDate = values.contentModificationDate ?? Date.distantPast
            let createDate = values.creationDate

            let file = DownloadedFile(
                id: UUID().uuidString,
                fileName: fileName,
                fileExtension: ext,
                fileURL: fileURL,
                fileSize: fileSize,
                modificationDate: modDate,
                creationDate: createDate,
                fileType: DownloadedFileType.from(extension: ext)
            )
            allFiles.append(file)
        }

        allFiles.sort { $0.fileSize > $1.fileSize }

        let filteredFiles = allFiles.filter { $0.meetsFilterCriteria }
        let totalSize = allFiles.reduce(Int64(0)) { $0 + $1.fileSize }
        let filteredSize = filteredFiles.reduce(Int64(0)) { $0 + $1.fileSize }

        return DownloadsScanResult(
            totalFiles: allFiles.count,
            totalSizeBytes: totalSize,
            filteredFiles: filteredFiles,
            filteredSizeBytes: filteredSize,
            allFiles: allFiles,
            folderName: folderURL.lastPathComponent
        )
    }
}
