import Foundation

/// A group of 2+ photos identified as duplicates (Hamming distance <= threshold).
struct DuplicateGroup: Identifiable, Equatable {
    let id: UUID
    let photos: [PhotoHash]
    let bestResultIndex: Int

    /// Total size of all photos in the group
    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }

    /// Size that can be saved by deleting all except the best result
    var potentialSavings: Int64 {
        photos.enumerated()
            .filter { $0.offset != bestResultIndex }
            .reduce(0) { $0 + $1.element.fileSize }
    }

    /// Number of photos in the group
    var count: Int { photos.count }

    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}
