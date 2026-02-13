import SwiftUI

/// Enum for each dashboard category card with display metadata
enum MediaCategory: String, CaseIterable, Identifiable {
    case duplicates
    case similar
    case similarVideos
    case similarScreenshots
    case screenshots
    case videos
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .duplicates:          return "Duplicata"
        case .similar:             return "Similar"
        case .similarVideos:       return "Vídeos similares"
        case .similarScreenshots:  return "Capturas de tela semelhantes"
        case .screenshots:         return "Capturas de tela"
        case .videos:              return "Vídeos"
        case .other:               return "Outro"
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
        case .other:               return Color(hex: "8E8E93")
        }
    }

    /// Display order on dashboard
    static var dashboardOrder: [MediaCategory] {
        [.duplicates, .similar, .similarVideos, .similarScreenshots, .screenshots, .videos, .other]
    }
}
