import CoreServices
import Foundation

final class DirectoryWatcher {
    enum WatcherError: Error {
        case failedToCreate
    }

    private var stream: FSEventStreamRef?
    private let eventHandler: () -> Void

    init(url: URL, eventHandler: @escaping () -> Void) throws {
        self.eventHandler = eventHandler

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.eventHandler()
        }

        let paths = [url.path] as CFArray

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        ) else {
            throw WatcherError.failedToCreate
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func cancel() {
        guard let stream = stream else { return }
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        cancel()
    }
}
