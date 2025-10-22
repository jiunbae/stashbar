import AppKit
import Foundation

final class FileIconCache {
    static let shared = FileIconCache()

    private let cache = NSCache<NSString, NSImage>()

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

    private func cacheKey(for url: URL, size: CGSize) -> NSString {
        NSString(string: "\(url.path)|\(Int(size.width))x\(Int(size.height))")
    }

    private func cost(for size: CGSize) -> Int {
        Int(size.width * size.height)
    }
}
