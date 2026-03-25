import SwiftUI

/// Enum for each dashboard category card with display metadata
enum MediaCategory: String, CaseIterable, Identifiable {
    case duplicates
    case similar
    case similarVideos
    case similarScreenshots
    case screenshots
    case videos
    case downloads
    case trashBin
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .duplicates:          return NSLocalizedString("category.duplicates", comment: "")
        case .similar:             return NSLocalizedString("category.similar", comment: "")
        case .similarVideos:       return NSLocalizedString("category.similarVideos", comment: "")
        case .similarScreenshots:  return NSLocalizedString("category.similarScreenshots", comment: "")
        case .screenshots:         return NSLocalizedString("category.screenshots", comment: "")
        case .videos:              return NSLocalizedString("category.videos", comment: "")
        case .downloads:           return NSLocalizedString("category.downloads", comment: "")
        case .trashBin:            return NSLocalizedString("category.trashBin", comment: "")
        case .other:               return NSLocalizedString("category.other", comment: "")
        }
    }

    /// Whether this category shows two side-by-side thumbnails (comparison layout)
    var showsComparisonLayout: Bool {
        switch self {
        case .duplicates, .similar: return true
        default: return false
        }
    }

    /// SF Symbol icon name for the card (fallback when no thumbnails available)
    var iconName: String {
        switch self {
        case .duplicates:          return "doc.on.doc.fill"
        case .similar:             return "square.on.square.fill"
        case .similarVideos:       return "video.badge.ellipsis"
        case .similarScreenshots:  return "rectangle.on.rectangle"
        case .screenshots:         return "camera.viewfinder"
        case .videos:              return "video.fill"
        case .downloads:           return "arrow.down.circle.fill"
        case .trashBin:            return "trash.fill"
        case .other:               return "folder.fill"
        }
    }

    /// Icon color for the category
    var iconColor: Color {
        switch self {
        case .duplicates:          return ColorTokens.destructiveRed
        case .similar:             return ColorTokens.warningOrange
        case .similarVideos:       return ColorTokens.primaryBlue
        case .similarScreenshots:  return Color(hex: "8E8E93")
        case .screenshots:         return Color(hex: "5856D6")
        case .videos:              return ColorTokens.primaryBlue
        case .downloads:           return ColorTokens.warningOrange
        case .trashBin:            return ColorTokens.destructiveRed
        case .other:               return Color(hex: "8E8E93")
        }
    }

    /// Display order on dashboard (similarVideos and similarScreenshots hidden until V2)
    static var dashboardOrder: [MediaCategory] {
        [.duplicates, .similar, .screenshots, .videos, .downloads, .trashBin]
    }
}
