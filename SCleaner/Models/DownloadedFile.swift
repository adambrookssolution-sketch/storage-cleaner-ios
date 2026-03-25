import Foundation
import SwiftUI

/// Represents a file discovered in the user's selected Downloads folder.
struct DownloadedFile: Identifiable, Equatable, Hashable {
    let id: String
    let fileName: String
    let fileExtension: String
    let fileURL: URL
    let fileSize: Int64
    let modificationDate: Date
    let creationDate: Date?
    let fileType: DownloadedFileType

    var formattedSize: String { fileSize.formattedSize }

    var formattedModificationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale.current
        return formatter.string(from: modificationDate)
    }

    var isStale: Bool {
        let threshold = Calendar.current.date(
            byAdding: .month,
            value: -AppConstants.Downloads.staleMonths,
            to: Date()
        ) ?? Date()
        return modificationDate < threshold
    }

    var isLarge: Bool {
        fileSize > AppConstants.Downloads.minimumFileSizeBytes
    }

    var meetsFilterCriteria: Bool {
        isLarge && isStale
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DownloadedFile, rhs: DownloadedFile) -> Bool { lhs.id == rhs.id }
}

enum DownloadedFileType: String, CaseIterable {
    case document
    case image
    case video
    case audio
    case archive
    case other

    var iconName: String {
        switch self {
        case .document: return "doc.fill"
        case .image:    return "photo.fill"
        case .video:    return "video.fill"
        case .audio:    return "music.note"
        case .archive:  return "archivebox.fill"
        case .other:    return "doc.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .document: return ColorTokens.primaryBlue
        case .image:    return ColorTokens.successGreen
        case .video:    return ColorTokens.warningOrange
        case .audio:    return Color(hex: "5856D6")
        case .archive:  return Color(hex: "8E8E93")
        case .other:    return Color(hex: "8E8E93")
        }
    }

    static func from(extension ext: String) -> DownloadedFileType {
        switch ext.lowercased() {
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "keynote":
            return .document
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv":
            return .video
        case "mp3", "wav", "m4a", "aac", "flac", "ogg", "wma":
            return .audio
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg":
            return .archive
        default:
            return .other
        }
    }
}
