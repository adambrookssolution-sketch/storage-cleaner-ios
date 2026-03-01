import Foundation

/// Represents a file currently in the app's internal trash bin.
struct TrashedFile: Identifiable, Codable, Equatable {
    let id: String
    let originalFileName: String
    let originalFolderBookmark: Data?
    let originalRelativePath: String
    let fileSize: Int64
    let deletionDate: Date
    let fileType: String

    var formattedSize: String { fileSize.formattedSize }

    var formattedDeletionDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: deletionDate)
    }

    var daysUntilPurge: Int {
        let purgeDate = Calendar.current.date(
            byAdding: .day,
            value: AppConstants.TrashBin.purgeAfterDays,
            to: deletionDate
        ) ?? Date()
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: purgeDate).day ?? 0
        return max(0, remaining)
    }

    var isExpired: Bool {
        daysUntilPurge <= 0
    }

    var storedFileName: String {
        let ext = (originalFileName as NSString).pathExtension
        return ext.isEmpty ? id : "\(id).\(ext)"
    }
}
