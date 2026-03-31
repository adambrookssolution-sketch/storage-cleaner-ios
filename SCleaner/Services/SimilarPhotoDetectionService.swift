import Foundation
import UIKit

/// Detects similar (but not duplicate) photos using perceptual hash comparison.
/// Groups photos with Hamming distance 11-20.
final class SimilarPhotoDetectionService {

    private let bestResultSelector = DuplicateDetectionService()

    /// Finds similar photo groups, excluding photos already in duplicate groups.
    func findSimilarGroups(
        from hashes: [PhotoHash],
        excludingDuplicateIds: Set<String>
    ) -> [SimilarGroup] {
        // Filter out photos already identified as duplicates
        let candidates = hashes.filter { !excludingDuplicateIds.contains($0.id) }
        let count = candidates.count
        guard count >= 2 else { return [] }

        let dupThreshold = AppConstants.Hashing.duplicateThreshold
        let simThreshold = AppConstants.Hashing.similarThreshold

        // Union-Find
        var parent = Array(0..<count)
        var rank = Array(repeating: 0, count: count)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]] // Path halving
                x = parent[x]
            }
            return x
        }

        func union(_ x: Int, _ y: Int) {
            let rx = find(x), ry = find(y)
            guard rx != ry else { return }
            if rank[rx] < rank[ry] { parent[rx] = ry }
            else if rank[rx] > rank[ry] { parent[ry] = rx }
            else { parent[ry] = rx; rank[rx] += 1 }
        }

        // Sort and compare within window
        let sorted = candidates.enumerated().sorted { $0.element.hash < $1.element.hash }
        let windowSize = AppConstants.Hashing.similarWindowSize

        for i in 0..<(count - 1) {
            let upperBound = min(i + windowSize, count)
            for j in (i + 1)..<upperBound {
                let dist = UIImage.hammingDistance(
                    sorted[i].element.hash,
                    sorted[j].element.hash
                )
                if dist > dupThreshold && dist <= simThreshold {
                    union(sorted[i].offset, sorted[j].offset)
                }
            }
        }

        // Collect groups
        var groupMap: [Int: [Int]] = [:]
        for i in 0..<count {
            let root = find(i)
            groupMap[root, default: []].append(i)
        }

        // Cap individual groups at 20 photos to prevent memory explosion in the UI.
        // If a group has more, split into sub-groups of 20.
        let maxGroupSize = 20
        var allGroups: [SimilarGroup] = []

        for indices in groupMap.values where indices.count >= 2 {
            let photos = indices.map { candidates[$0] }

            // Split large groups into manageable chunks
            let chunks: [[PhotoHash]]
            if photos.count > maxGroupSize {
                chunks = stride(from: 0, to: photos.count, by: maxGroupSize).map {
                    Array(photos[$0..<min($0 + maxGroupSize, photos.count)])
                }.filter { $0.count >= 2 }
            } else {
                chunks = [photos]
            }

            for chunk in chunks {
                let samplePhotos = chunk.count > 10 ? Array(chunk.prefix(10)) : chunk
                var totalDist = 0
                var pairCount = 0
                for a in 0..<samplePhotos.count {
                    for b in (a + 1)..<samplePhotos.count {
                        totalDist += UIImage.hammingDistance(samplePhotos[a].hash, samplePhotos[b].hash)
                        pairCount += 1
                    }
                }
                let avgDist = pairCount > 0 ? totalDist / pairCount : 0
                let bestIndex = bestResultSelector.selectBestResult(from: chunk)

                allGroups.append(SimilarGroup(
                    id: UUID(),
                    photos: chunk,
                    bestResultIndex: bestIndex,
                    averageDistance: avgDist
                ))
            }
        }

        return allGroups.sorted { $0.totalSize > $1.totalSize }
    }
}
