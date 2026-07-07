import Foundation

public struct FileSystemEntry: Identifiable {
    public let file: FileItem
    public var children: [FileSystemEntry]?

    public var id: String { file.id }
    public var isDirectory: Bool { file.isDirectory }

    public init(file: FileItem, children: [FileSystemEntry]?) {
        self.file = file
        self.children = children
    }
}

public enum FileTreeBuilder {
    private static let resourceKeys: Set<URLResourceKey> = [
        .localizedNameKey,
        .contentModificationDateKey,
        .typeIdentifierKey,
        .fileSizeKey,
        .isDirectoryKey
    ]

    public static func buildTree(at rootURL: URL, depthLimit: Int = 3, childLimit: Int = 80) -> FileSystemEntry? {
        guard let values = try? rootURL.resourceValues(forKeys: resourceKeys) else {
            return nil
        }
        let rootItem = FileItem(url: rootURL, values: values)
        let children = loadChildren(of: rootURL, depthRemaining: depthLimit, childLimit: childLimit)
        return FileSystemEntry(file: rootItem, children: children.isEmpty ? nil : children)
    }

    private static func loadChildren(of url: URL, depthRemaining: Int, childLimit: Int) -> [FileSystemEntry] {
        guard depthRemaining > 0 else { return [] }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let entries: [FileSystemEntry] = contents.compactMap { childURL in
            guard let values = try? childURL.resourceValues(forKeys: resourceKeys) else {
                return nil
            }
            let item = FileItem(url: childURL, values: values)
            if item.isDirectory {
                let children = loadChildren(of: childURL, depthRemaining: depthRemaining - 1, childLimit: childLimit)
                return FileSystemEntry(file: item, children: children.isEmpty ? nil : children)
            } else {
                return FileSystemEntry(file: item, children: nil)
            }
        }

        let sorted = entries.sorted { lhs, rhs in
            switch (lhs.isDirectory, rhs.isDirectory) {
            case (true, false): return true
            case (false, true): return false
            default:
                return lhs.file.displayName.localizedCaseInsensitiveCompare(rhs.file.displayName) == .orderedAscending
            }
        }

        return Array(sorted.prefix(childLimit))
    }
}