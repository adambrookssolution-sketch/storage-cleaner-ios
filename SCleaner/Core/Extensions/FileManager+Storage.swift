import Foundation
#if targetEnvironment(simulator)
import UIKit
#endif

extension FileManager {
    /// Returns device storage info: (totalCapacity, availableCapacity, usedCapacity) in bytes.
    /// On simulator, uses volumeTotalCapacity for more accurate results.
    /// On real devices, uses both systemSize and volumeAvailableCapacityForImportantUsage.
    static func deviceStorageInfo() -> (total: Int64, available: Int64, used: Int64) {
        // Try URL resource values first (more reliable on iOS)
        if let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let values = try? docURL.resourceValues(forKeys: [
               .volumeTotalCapacityKey,
               .volumeAvailableCapacityForImportantUsageKey
           ]),
           let totalCapacity = values.volumeTotalCapacity,
           let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
            let total = Int64(totalCapacity)
            let available = availableCapacity
            let used = max(0, total - available)

            #if targetEnvironment(simulator)
            // On simulator, the disk is the Mac's disk (often 500GB-4TB).
            // Cap to a realistic iPhone size for proper UI display.
            let maxRealisticCapacity: Int64 = 512_000_000_000 // 512 GB
            if total > maxRealisticCapacity {
                let simulatedTotal: Int64 = 256_000_000_000 // 256 GB
                let usageRatio = Double(used) / Double(total)
                let simulatedUsed = Int64(Double(simulatedTotal) * usageRatio)
                let simulatedAvailable = simulatedTotal - simulatedUsed
                return (simulatedTotal, simulatedAvailable, simulatedUsed)
            }
            #endif

            return (total, available, used)
        }

        // Fallback to legacy attributesOfFileSystem
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) else {
            return (0, 0, 0)
        }
        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free = (attrs[.systemFreeSize] as? Int64) ?? 0
        let used = total - free

        #if targetEnvironment(simulator)
        let maxRealisticCapacity: Int64 = 512_000_000_000
        if total > maxRealisticCapacity {
            let simulatedTotal: Int64 = 256_000_000_000
            let usageRatio = Double(used) / Double(total)
            let simulatedUsed = Int64(Double(simulatedTotal) * usageRatio)
            let simulatedAvailable = simulatedTotal - simulatedUsed
            return (simulatedTotal, simulatedAvailable, simulatedUsed)
        }
        #endif

        return (total, free, used)
    }

    /// Returns available capacity for important usage (more accurate on iOS)
    static func availableCapacityForImportantUsage() -> Int64 {
        guard let url = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first,
              let values = try? url.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
              ),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return 0
        }
        return capacity
    }
}
