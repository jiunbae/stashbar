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

    func loadThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }
        return await withCheckedContinuation { continuation in
            requestThumbnail(for: url, size: size) { image in
                continuation.resume(returning: image)
            }
        }
    }

    func prefetch(urls: [URL], size: CGSize) {
        queue.async { [weak self] in
            guard let self else { return }
            for url in urls {
                if self.image(for: url) != nil { continue }
                self.requestThumbnail(for: url, size: size, completion: { _ in })
            }
        }
    }

    /// Coalesces concurrent requests for the same URL: only the first request dispatches
    /// to QLThumbnailGenerator; subsequent requests attach their completion to the
    /// in-flight list and fire when the original completes.
    private func requestThumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
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
            self.generateThumbnail(for: url, size: size) { [weak self] image in
                guard let self else { return }
                self.inFlightLock.lock()
                let callbacks = self.inFlight.removeValue(forKey: url) ?? []
                self.inFlightLock.unlock()
                for callback in callbacks {
                    callback(image)
                }
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
                autoreleasepool {
                    if let representation {
                        let cgImage = representation.cgImage
                        let renderedSize = NSSize(width: size.width, height: size.height)
                        let image = NSImage(cgImage: cgImage, size: renderedSize)
                        ThumbnailCache.shared.store(image, for: url)
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
