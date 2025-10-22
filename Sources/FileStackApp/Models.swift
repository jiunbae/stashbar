import Foundation

struct FileItem: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let modificationDate: Date?
    let fileSize: Int64?
    let typeIdentifier: String?
    let isDirectory: Bool

    var id: String { url.path }

    var relativeDateDescription: String {
        guard let date = modificationDate else { return "알 수 없음" }
        return FileItem.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(url: URL, values: URLResourceValues) {
        self.url = url
        self.displayName = values.localizedName ?? url.lastPathComponent
        self.modificationDate = values.contentModificationDate
        self.fileSize = values.fileSize.map(Int64.init)
        self.typeIdentifier = values.typeIdentifier
        self.isDirectory = values.isDirectory ?? false
    }
}

struct WatchedFolder: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var files: [FileItem]

    var displayName: String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }
}

enum FileViewMode: String, CaseIterable, Identifiable {
    case icon
    case list
    case hierarchy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icon: return "아이콘"
        case .list: return "목록"
        case .hierarchy: return "계층"
        }
    }

    var systemImageName: String {
        switch self {
        case .icon: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .hierarchy: return "rectangle.split.3x1"
        }
    }
}
