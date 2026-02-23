import Foundation
import UIKit

/// Detects duplicate photos using perceptual hash comparison with Union-Find clustering.
final class DuplicateDetectionService {

    // MARK: - Union-Find Data Structure

    private final class UnionFind {
        private var parent: [Int]
        private var rank: [Int]

        init(count: Int) {
            parent = Array(0..<count)
            rank = Array(repeating: 0, count: count)
        }

        func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x]) // Path compression
            }
            return parent[x]
        }

        func union(_ x: Int, _ y: Int) {
            let rootX = find(x)
            let rootY = find(y)
            guard rootX != rootY else { return }

            if rank[rootX] < rank[rootY] {
                parent[rootX] = rootY
            } else if rank[rootX] > rank[rootY] {
                parent[rootY] = rootX
            } else {
                parent[rootY] = rootX
                rank[rootX] += 1
            }
        }
    }

    // MARK: - Public API

    /// Finds all duplicate groups from an array of photo hashes.
    /// Uses Union-Find with Hamming distance <= threshold.
    func findDuplicates(from hashes: [PhotoHash]) -> [DuplicateGroup] {
        let count = hashes.count
        guard count >= 2 else { return [] }

        let threshold = AppConstants.Hashing.duplicateThreshold
        let uf = UnionFind(count: count)

        // Sort by hash value for locality-friendly comparison
        let sorted = hashes.enumerated().sorted { $0.element.hash < $1.element.hash }

        // Compare each hash within a sliding window
        let windowSize = 200
        for i in 0..<(count - 1) {
            let upperBound = min(i + windowSize, count)
            for j in (i + 1)..<upperBound {
                let dist = UIImage.hammingDistance(
                    sorted[i].element.hash,
                    sorted[j].element.hash
                )
                if dist <= threshold {
                    uf.union(sorted[i].offset, sorted[j].offset)
                }
            }
        }

        // Collect groups
        var groupMap: [Int: [Int]] = [:]
        for i in 0..<count {
            let root = uf.find(i)
            groupMap[root, default: []].append(i)
        }

        // Filter to groups of 2+ and build DuplicateGroup structs
        return groupMap.values
            .filter { $0.count >= 2 }
            .map { indices in
                let photos = indices.map { hashes[$0] }
                let bestIndex = selectBestResult(from: photos)
                return DuplicateGroup(
                    id: UUID(),
                    photos: photos,
                    bestResultIndex: bestIndex
                )
            }
            .sorted { $0.totalSize > $1.totalSize }
    }

    // MARK: - Best Result Selection

    /// Selects the "best" photo to keep from a group.
    /// Priority: highest resolution > not edited > favorite > newest
    func selectBestResult(from photos: [PhotoHash]) -> Int {
        guard photos.count > 1 else { return 0 }

        let maxPixels = photos.map(\.pixelCount).max() ?? 1

        let scored = photos.enumerated().map { (index, photo) -> (Int, Double) in
            var score: Double = 0

            // Resolution score (normalized, weight: 100)
            score += (Double(photo.pixelCount) / Double(max(maxPixels, 1))) * 100

            // Not edited bonus (weight: 50)
            if !photo.isEdited {
                score += 50
            }

            // Favorite bonus (weight: 30)
            if photo.isFavorite {
                score += 30
            }

            // Newer is better (weight: small tiebreaker)
            if let date = photo.creationDate {
                score += date.timeIntervalSince1970 / 1_000_000_000
            }

            return (index, score)
        }

        return scored.max(by: { $0.1 < $1.1 })?.0 ?? 0
    }
}
