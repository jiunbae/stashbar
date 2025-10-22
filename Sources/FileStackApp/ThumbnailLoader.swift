import AppKit
import Foundation

@MainActor
final class ThumbnailLoader: ObservableObject {
    @Published private(set) var image: NSImage?

    private let file: FileItem

    init(file: FileItem) {
        self.file = file
    }

    func ensureLoaded(targetSize: CGSize) async {
        if image != nil {
            return
        }

        if file.isDirectory {
            image = FileIconCache.shared.icon(for: file.url, size: targetSize)
            return
        }

        if let cached = ThumbnailCache.shared.image(for: file.url) {
            image = cached
            return
        }

        let loaded = await ThumbnailCache.shared.loadThumbnail(for: file.url, size: targetSize)
        if let loaded {
            image = loaded
        } else {
            image = FileIconCache.shared.icon(for: file.url, size: targetSize)
        }
    }
}
