import Foundation

struct FileItem: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let modificationDate: Date?
    let fileSize: Int64?
    let typeIdentifier: String?

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
