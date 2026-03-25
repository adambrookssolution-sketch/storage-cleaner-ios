import UIKit

/// Non-reactive thumbnail store that does NOT trigger SwiftUI re-renders.
/// Used by ViewModels to cache thumbnails without @Published overhead.
/// Views access thumbnails via subscript; individual cells reload via .onAppear.
final class ThumbnailStore {
    private var cache: [String: UIImage] = [:]
    private var accessOrder: [String] = []
    private let maxCount: Int

    init(maxCount: Int = 200) {
        self.maxCount = maxCount
    }

    subscript(key: String) -> UIImage? {
        get {
            guard let image = cache[key] else { return nil }
            // Move to end (most recently used)
            if let idx = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: idx)
            }
            accessOrder.append(key)
            return image
        }
        set {
            if let image = newValue {
                store(image, forKey: key)
            } else {
                cache.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
            }
        }
    }

    var count: Int { cache.count }

    func contains(_ key: String) -> Bool {
        cache[key] != nil
    }

    func removeAll() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    func remove(_ key: String) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    func removeAll(where predicate: (String) -> Bool) {
        let toRemove = cache.keys.filter(predicate)
        for key in toRemove {
            cache.removeValue(forKey: key)
        }
        accessOrder.removeAll { predicate($0) }
    }

    private func store(_ image: UIImage, forKey key: String) {
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return
        }
        while cache.count >= maxCount, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        cache[key] = image
        accessOrder.append(key)
    }
}
