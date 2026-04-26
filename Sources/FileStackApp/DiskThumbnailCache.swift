import AppKit
import CryptoKit
import Foundation
import os.log

/// Persistent disk cache for thumbnails. Survives app restarts so that a freshly-launched
/// popover can show real thumbnails immediately without re-running QuickLook generation.
///
/// Layout: `~/Library/Caches/com.file-stack.app/thumbnails/<sha256(path)>.png`
/// Staleness: cache file's mtime is set to the source file's mtime; on lookup we compare
/// the two and discard the cached entry when the source is newer. This avoids serving
/// stale previews after a file edit.
final class DiskThumbnailCache: @unchecked Sendable {
    static let shared = DiskThumbnailCache()

    private let directory: URL
    private let ioQueue = DispatchQueue(label: "com.file-stack.thumbnail-disk", qos: .utility)
    private let logger = Logger(subsystem: "com.file-stack.app", category: "thumbnail-disk")
    private let maxBytes: Int = 200 * 1024 * 1024 // 200 MB
    private let cleanupBudget: Int = 150 * 1024 * 1024 // trim down to this on cleanup

    private init() {
        let fileManager = FileManager.default
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = cachesDir.appendingPathComponent("com.file-stack.app/thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // Trim opportunistically on startup to clean up orphaned entries from prior runs.
        ioQueue.async { [weak self] in
            self?.cleanupIfNeeded()
        }
    }

    /// Returns a cached thumbnail if one exists AND is at least as recent as the source file.
    /// Sync read — callers should already be off the main thread.
    func image(for url: URL, sourceModified: Date) -> NSImage? {
        let path = filePath(for: url)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
        guard let cachedMtime = attrs?[.modificationDate] as? Date else { return nil }
        // Allow 1s slack to account for filesystem mtime precision.
        guard cachedMtime.timeIntervalSince(sourceModified) >= -1 else { return nil }
        return NSImage(contentsOf: path)
    }

    /// Persists the thumbnail and stamps the cache entry's mtime with the source file's mtime.
    func store(_ image: NSImage, for url: URL, sourceModified: Date) {
        let path = filePath(for: url)
        ioQueue.async { [weak self] in
            guard let self else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return
            }
            do {
                try pngData.write(to: path, options: .atomic)
                try FileManager.default.setAttributes(
                    [.modificationDate: sourceModified],
                    ofItemAtPath: path.path
                )
            } catch {
                self.logger.debug("Failed to persist thumbnail for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Removes the entry for a single URL — used when generation fails so we don't keep stale data.
    func remove(for url: URL) {
        let path = filePath(for: url)
        ioQueue.async {
            try? FileManager.default.removeItem(at: path)
        }
    }

    /// LRU-by-mtime cleanup when total cache size exceeds maxBytes. Async on the IO queue.
    private func cleanupIfNeeded() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var infos: [(url: URL, size: Int, mtime: Date)] = []
        var totalSize = 0
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let mtime = values.contentModificationDate else { continue }
            infos.append((entry, size, mtime))
            totalSize += size
        }

        guard totalSize > maxBytes else { return }

        // Oldest first — evict until we fit in cleanupBudget.
        infos.sort { $0.mtime < $1.mtime }
        for info in infos {
            if totalSize <= cleanupBudget { break }
            try? fm.removeItem(at: info.url)
            totalSize -= info.size
        }
    }

    private func filePath(for url: URL) -> URL {
        let bytes = Data(url.path.utf8)
        let digest = SHA256.hash(data: bytes)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hex).png")
    }
}
