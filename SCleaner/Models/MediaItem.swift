import UIKit

/// Lightweight display-oriented model wrapping a PHAsset local identifier
struct MediaItem: Identifiable, Equatable, Hashable {
    let id: String              // PHAsset.localIdentifier
    let mediaType: MediaItemType
    let creationDate: Date?
    let fileSize: Int64
    var thumbnail: UIImage?

    enum MediaItemType: Equatable, Hashable {
        case photo
        case video
        case screenshot
    }

    var formattedSize: String {
        fileSize.formattedSize
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}
