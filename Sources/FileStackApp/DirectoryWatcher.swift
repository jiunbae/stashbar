import CoreServices
import Foundation

final class DirectoryWatcher {
    enum WatcherError: Error {
        case failedToCreateStream
        case failedToStartStream
    }

    private var stream: FSEventStreamRef?
    private let eventHandler: () -> Void
    private let fsQueue = DispatchQueue(label: "com.filestack.directorywatcher")

    private class WeakBox {
        weak var watcher: DirectoryWatcher?
        init(_ watcher: DirectoryWatcher) {
            self.watcher = watcher
        }
    }

    init(url: URL, eventHandler: @escaping () -> Void) throws {
        self.eventHandler = eventHandler

        let weakBox = WeakBox(self)
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passRetained(weakBox).toOpaque()
        context.release = { ptr in
            guard let ptr = ptr else { return }
            Unmanaged<WeakBox>.fromOpaque(ptr).release()
        }

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let box = Unmanaged<WeakBox>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async {
                box.watcher?.eventHandler()
            }
        }

        let paths = [url.path] as CFArray

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer)
        ) else {
            if let info = context.info {
                Unmanaged<WeakBox>.fromOpaque(info).release()
            }
            throw WatcherError.failedToCreateStream
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, fsQueue)
        if !FSEventStreamStart(stream) {
            cancel()
            throw WatcherError.failedToStartStream
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
