import Foundation

extension FileManager {
    /// Returns device storage info: (totalCapacity, availableCapacity, usedCapacity) in bytes
    static func deviceStorageInfo() -> (total: Int64, available: Int64, used: Int64) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) else {
            return (0, 0, 0)
        }
        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free = (attrs[.systemFreeSize] as? Int64) ?? 0
        let used = total - free
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
