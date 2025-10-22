import Darwin
import Foundation

final class DirectoryWatcher {
    enum WatcherError: Error {
        case failedToOpen(errno: Int32)
    }

    private let fileDescriptor: CInt
    private let source: DispatchSourceFileSystemObject

    init(url: URL, eventHandler: @escaping () -> Void) throws {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else {
            throw WatcherError.failedToOpen(errno: errno)
        }
        fileDescriptor = descriptor
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        source.setEventHandler(handler: eventHandler)
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
    }

    func cancel() {
        source.cancel()
    }

    deinit {
        source.cancel()
    }
}
