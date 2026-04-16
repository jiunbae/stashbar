import AppKit
import Foundation
import os.log
import QuickLookThumbnailing

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "com.file-stack.thumbnail", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.file-stack.app", category: "thumbnail")
    private let screenScale: CGFloat = {
        // Captured once during init on main thread
        NSScreen.main?.backingScaleFactor ?? 2.0
    }()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: NSImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            queue.async {
                self.generateThumbnail(for: url, size: size) { image in
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func prefetch(urls: [URL], size: CGSize) {
        queue.async {
            for url in urls {
                if self.image(for: url) != nil { continue }
                self.generateThumbnail(for: url, size: size, completion: { _ in })
            }
        }
    }

    private func generateThumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        autoreleasepool {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: screenScale,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let representation {
                    let cgImage = representation.cgImage
                    let renderedSize = NSSize(width: size.width, height: size.height)
                    let image = NSImage(cgImage: cgImage, size: renderedSize)
                    ThumbnailCache.shared.store(image, for: url)
                    completion(image)
                } else {
                    let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
                    icon?.size = NSSize(width: size.width, height: size.height)
                    if let icon {
                        ThumbnailCache.shared.store(icon, for: url)
                        completion(icon)
                    } else {
                        completion(nil)
                    }
                    if let error {
                        self.logger.debug("Thumbnail generation failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }
}
