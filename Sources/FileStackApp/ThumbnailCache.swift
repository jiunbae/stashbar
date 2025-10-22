import AppKit
import Foundation
import QuickLookThumbnailing

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: NSImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2.0,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let representation {
                    let cgImage = representation.cgImage
                    let renderedSize = NSSize(width: size.width, height: size.height)
                    let image = NSImage(cgImage: cgImage, size: renderedSize)
                    ThumbnailCache.shared.store(image, for: url)
                    continuation.resume(returning: image)
                } else {
                    let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
                    icon?.size = NSSize(width: size.width, height: size.height)
                    if let icon {
                        ThumbnailCache.shared.store(icon, for: url)
                        continuation.resume(returning: icon)
                    } else {
                        continuation.resume(returning: nil)
                    }
                    if let error {
                        NSLog("Thumbnail generation failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
