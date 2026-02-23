import Foundation
import Photos

/// Perceptual hash data for a single photo asset.
/// Stores the 64-bit dHash plus metadata needed for best-result selection.
struct PhotoHash: Identifiable, Hashable {
    let id: String          // PHAsset.localIdentifier
    let hash: UInt64        // 64-bit dHash
    let creationDate: Date?
    let fileSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let mediaSubtypes: UInt // Raw value of PHAssetMediaSubtype

    /// Total pixel count for resolution comparison
    var pixelCount: Int { pixelWidth * pixelHeight }

    /// Whether the asset has been edited
    var isEdited: Bool {
        let editSubtype = PHAssetMediaSubtype(rawValue: mediaSubtypes)
        // Check for any adjustments applied to the photo
        return editSubtype.contains(.photoScreenshot) == false
            && (mediaSubtypes & 0x10) != 0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoHash, rhs: PhotoHash) -> Bool {
        lhs.id == rhs.id
    }
}
