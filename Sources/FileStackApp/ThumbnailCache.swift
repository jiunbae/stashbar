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
        NSScreen.main?.backingScaleFactor ?? 2.0
    }()

    /// Tracks active generation requests so concurrent callers for the same URL share a
    /// single QLThumbnailGenerator request instead of triggering duplicates.
    private let inFlightLock = NSLock()
    private var inFlight: [URL: [(NSImage?) -> Void]] = [:]

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

    func loadThumbnail(for url: URL, size: CGSize, sourceModified: Date? = nil) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }
        return await withCheckedContinuation { continuation in
            requestThumbnail(for: url, size: size, sourceModified: sourceModified) { image in
                continuation.resume(returning: image)
            }
        }
    }

    func prefetch(urls: [(url: URL, sourceModified: Date?)], size: CGSize) {
        queue.async { [weak self] in
            guard let self else { return }
            for entry in urls {
                if self.image(for: entry.url) != nil { continue }
                self.requestThumbnail(for: entry.url, size: size, sourceModified: entry.sourceModified, completion: { _ in })
            }
        }
    }

    /// Coalesces concurrent requests for the same URL: only the first request hits disk
    /// and (if that misses) QuickLookGenerator; subsequent requests attach a callback to
    /// the in-flight list and wake when the original resolves.
    private func requestThumbnail(
        for url: URL,
        size: CGSize,
        sourceModified: Date?,
        completion: @escaping (NSImage?) -> Void
    ) {
        if let cached = image(for: url) {
            completion(cached)
            return
        }

        inFlightLock.lock()
        if inFlight[url] != nil {
            inFlight[url]?.append(completion)
            inFlightLock.unlock()
            return
        }
        inFlight[url] = [completion]
        inFlightLock.unlock()

        queue.async { [weak self] in
            guard let self else { return }

            // Try disk cache before paying for QuickLook generation.
            if let mtime = sourceModified,
               let diskImage = DiskThumbnailCache.shared.image(for: url, sourceModified: mtime) {
                self.store(diskImage, for: url)
                self.fireInFlight(for: url, with: diskImage)
                return
            }

            self.generateThumbnail(for: url, size: size, sourceModified: sourceModified) { [weak self] image in
                self?.fireInFlight(for: url, with: image)
            }
        }
    }

    private func fireInFlight(for url: URL, with image: NSImage?) {
        inFlightLock.lock()
        let callbacks = inFlight.removeValue(forKey: url) ?? []
        inFlightLock.unlock()
        for callback in callbacks {
            callback(image)
        }
    }

    private func generateThumbnail(
        for url: URL,
        size: CGSize,
        sourceModified: Date?,
        completion: @escaping (NSImage?) -> Void
    ) {
        autoreleasepool {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: screenScale,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                autoreleasepool {
                    if let representation {
                        let cgImage = representation.cgImage
                        let renderedSize = NSSize(width: size.width, height: size.height)
                        let image = NSImage(cgImage: cgImage, size: renderedSize)
                        ThumbnailCache.shared.store(image, for: url)
                        if let sourceModified {
                            DiskThumbnailCache.shared.store(image, for: url, sourceModified: sourceModified)
                        }
                        completion(image)
                    } else {
                        DispatchQueue.main.async {
                            let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
                            icon?.size = NSSize(width: size.width, height: size.height)
                            if let icon {
                                ThumbnailCache.shared.store(icon, for: url)
                                completion(icon)
                            } else {
                                completion(nil)
                            }
                        }
                        if let error {
                            self.logger.debug("Thumbnail generation failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }
        }
    }
}
