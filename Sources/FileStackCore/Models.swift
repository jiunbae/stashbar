import Foundation

#if canImport(AppKit)
import AppKit
#endif

public struct FileItem: Identifiable, Hashable {
    public let id: String
    public let url: URL
    public let displayName: String
    public let modificationDate: Date?
    public let fileSize: Int64?
    public let typeIdentifier: String?
    public let isDirectory: Bool
    public let tagNames: [String]?

    public var relativeDateDescription: String {
        guard let date = modificationDate else { return Localization.string("unknown") }
        return FileItem.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    public init(id: String, url: URL, displayName: String, modificationDate: Date?, fileSize: Int64?, typeIdentifier: String?, isDirectory: Bool, tagNames: [String]? = nil) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.modificationDate = modificationDate
        self.fileSize = fileSize
        self.typeIdentifier = typeIdentifier
        self.isDirectory = isDirectory
        self.tagNames = tagNames
    }

    public init(url: URL, values: URLResourceValues) {
        self.id = url.path
        self.url = url
        self.displayName = values.localizedName ?? url.lastPathComponent
        self.modificationDate = values.contentModificationDate
        self.fileSize = values.fileSize.map(Int64.init)
        self.typeIdentifier = values.typeIdentifier
        self.isDirectory = values.isDirectory ?? false
        self.tagNames = values.tagNames
    }
}

public struct WatchedFolder: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public var files: [FileItem]
    public var isFavorite: Bool

    public var displayName: String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    public init(id: UUID, url: URL, files: [FileItem], isFavorite: Bool = false) {
        self.id = id
        self.url = url
        self.files = files
        self.isFavorite = isFavorite
    }
}

public enum FileViewMode: String, CaseIterable, Identifiable {
    case icon
    case list
    case hierarchy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .icon: return Localization.string("view.mode.icon")
        case .list: return Localization.string("view.mode.list")
        case .hierarchy: return Localization.string("view.mode.hierarchy")
        }
    }

    public var systemImageName: String {
        switch self {
        case .icon: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .hierarchy: return "rectangle.split.3x1"
        }
    }
}

public enum SortOption: String, CaseIterable, Identifiable {
    case name
    case kind
    case dateModified
    case size

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .name: return Localization.string("sort.option.name")
        case .kind: return Localization.string("sort.option.kind")
        case .dateModified: return Localization.string("sort.option.dateModified")
        case .size: return Localization.string("sort.option.size")
        }
    }

    public var systemImageName: String {
        switch self {
        case .name: return "textformat"
        case .kind: return "doc"
        case .dateModified: return "calendar"
        case .size: return "chart.bar"
        }
    }
}

public extension FileItem {
    var primaryTagColor: NSColor? {
        guard let first = tagNames?.first else { return nil }
        switch first {
        case "Red": return .systemRed
        case "Orange": return .systemOrange
        case "Yellow": return .systemYellow
        case "Green": return .systemGreen
        case "Blue": return .systemBlue
        case "Purple": return .systemPurple
        case "Gray": return .systemGray
        default: return nil
        }
    }
}

public enum SortDirection: String, CaseIterable, Identifiable {
    case ascending
    case descending

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ascending: return Localization.string("sort.direction.ascending")
        case .descending: return Localization.string("sort.direction.descending")
        }
    }

    public var systemImageName: String {
        switch self {
        case .ascending: return "chevron.up"
        case .descending: return "chevron.down"
        }
    }
}