import UIKit

/// In-memory thumbnail cache. List cells read from the cache synchronously
/// (no disk I/O on the main thread) and load misses in the background once.
enum ThumbnailStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func cached(_ fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return cache.object(forKey: fileName as NSString)
    }

    static func load(_ fileName: String?) async -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        if let hit = cache.object(forKey: fileName as NSString) { return hit }

        let url = MediaStore.momentsDirectory.appendingPathComponent(fileName)
        return await Task.detached(priority: .utility) {
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            // Decode off the main thread so scrolling never pays for it.
            let decoded = image.preparingForDisplay() ?? image
            cache.setObject(decoded, forKey: fileName as NSString)
            return decoded
        }.value
    }

    /// Seeds the cache with an image we already have (e.g. right after saving).
    static func store(_ image: UIImage, for fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        cache.setObject(image, forKey: fileName as NSString)
    }

    static func invalidate(_ fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        cache.removeObject(forKey: fileName as NSString)
    }
}
