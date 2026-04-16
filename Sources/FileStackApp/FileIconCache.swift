import AppKit
import Foundation

final class FileIconCache {
    static let shared = FileIconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.file-stack.icon-cache", qos: .userInitiated)

    private init() {
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    func icon(for url: URL, size: CGSize) -> NSImage {
        let key = cacheKey(for: url, size: size)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let baseIcon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage) ?? NSImage(size: size)
        baseIcon.size = size
        cache.setObject(baseIcon, forKey: key, cost: cost(for: size))
        return baseIcon
    }

    func prefetch(urls: [URL], size: CGSize) {
        queue.async { [weak self] in
            guard let self else { return }
            for url in urls {
                let key = self.cacheKey(for: url, size: size)
                if self.cache.object(forKey: key) != nil { continue }
                let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage) ?? NSImage(size: size)
                icon.size = size
                self.cache.setObject(icon, forKey: key, cost: self.cost(for: size))
            }
        }
    }

    private func cacheKey(for url: URL, size: CGSize) -> NSString {
        NSString(string: "\(url.path)|\(Int(size.width))x\(Int(size.height))")
    }

    private func cost(for size: CGSize) -> Int {
        Int(size.width * size.height * 4)
    }
}
