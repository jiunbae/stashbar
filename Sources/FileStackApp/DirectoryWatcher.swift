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

        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passRetained(self).toOpaque()
        context.release = { ptr in
            guard let ptr = ptr else { return }
            Unmanaged<DirectoryWatcher>.fromOpaque(ptr).release()
        }

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
        if !FSEventStreamStart(stream) {
            cancel()
            throw WatcherError.failedToCreate
        }
    }

    func cancel() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        cancel()
    }
}
