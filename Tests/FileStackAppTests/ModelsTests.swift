import XCTest
@testable import FileStackCore

final class FileItemTests: XCTestCase {

    // MARK: - Memberwise init

    func testMemberwiseInit() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let date = Date(timeIntervalSince1970: 1_000_000)
        let item = FileItem(
            id: "/tmp/test.txt",
            url: url,
            displayName: "test.txt",
            modificationDate: date,
            fileSize: 42,
            typeIdentifier: "public.plain-text",
            isDirectory: false
        )

        XCTAssertEqual(item.id, "/tmp/test.txt")
        XCTAssertEqual(item.url, url)
        XCTAssertEqual(item.displayName, "test.txt")
        XCTAssertEqual(item.modificationDate, date)
        XCTAssertEqual(item.fileSize, 42)
        XCTAssertEqual(item.typeIdentifier, "public.plain-text")
        XCTAssertFalse(item.isDirectory)
    }

    func testDirectoryItem() {
        let url = URL(fileURLWithPath: "/tmp/MyFolder")
        let item = FileItem(
            id: "/tmp/MyFolder",
            url: url,
            displayName: "MyFolder",
            modificationDate: nil,
            fileSize: nil,
            typeIdentifier: nil,
            isDirectory: true
        )

        XCTAssertTrue(item.isDirectory)
        XCTAssertNil(item.modificationDate)
        XCTAssertNil(item.fileSize)
        XCTAssertNil(item.typeIdentifier)
    }

    // MARK: - Identifiable & Hashable

    func testIDUniqueness() {
        let a = makeFileItem(id: "/a")
        let b = makeFileItem(id: "/b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testHashableConformance() {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let a = makeFileItem(id: "/same", modificationDate: fixedDate)
        let b = makeFileItem(id: "/same", modificationDate: fixedDate)
        XCTAssertEqual(a, b)

        var set = Set<FileItem>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    func testDifferentIDsAreNotEqual() {
        let a = makeFileItem(id: "/a")
        let b = makeFileItem(id: "/b")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - relativeDateDescription

    func testRelativeDateDescriptionWithNilDate() {
        let item = makeFileItem(id: "/x", modificationDate: nil)
        // In test context, Localization.bundle has no .lproj files,
        // so NSLocalizedString returns the key itself as fallback.
        let expected = NSLocalizedString("unknown", bundle: Localization.bundle, comment: "")
        XCTAssertEqual(item.relativeDateDescription, expected)
    }

    func testRelativeDateDescriptionWithRecentDate() {
        let recent = Date().addingTimeInterval(-60) // 1 minute ago
        let item = makeFileItem(id: "/x", modificationDate: recent)
        // Just verify it doesn't crash and returns a non-empty string
        XCTAssertFalse(item.relativeDateDescription.isEmpty)
    }

    // MARK: - Helpers

    private func makeFileItem(
        id: String,
        modificationDate: Date? = Date(),
        fileSize: Int64? = 100,
        isDirectory: Bool = false
    ) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id),
            displayName: (id as NSString).lastPathComponent,
            modificationDate: modificationDate,
            fileSize: fileSize,
            typeIdentifier: isDirectory ? "public.folder" : "public.data",
            isDirectory: isDirectory
        )
    }
}

final class WatchedFolderTests: XCTestCase {

    func testDisplayNameFromURL() {
        let folder = WatchedFolder(
            id: UUID(),
            url: URL(fileURLWithPath: "/Users/test/Documents"),
            files: []
        )
        XCTAssertEqual(folder.displayName, "Documents")
    }

    func testDisplayNameEmptyPathComponent() {
        // Root path "/" has empty lastPathComponent
        let folder = WatchedFolder(
            id: UUID(),
            url: URL(fileURLWithPath: "/"),
            files: []
        )
        // lastPathComponent of "/" is "/", which is non-empty
        XCTAssertEqual(folder.displayName, "/")
    }

    func testEquatable() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp")
        let a = WatchedFolder(id: id, url: url, files: [])
        let b = WatchedFolder(id: id, url: url, files: [])
        XCTAssertEqual(a, b)
    }

    func testEquatableDifferentID() {
        let url = URL(fileURLWithPath: "/tmp")
        let a = WatchedFolder(id: UUID(), url: url, files: [])
        let b = WatchedFolder(id: UUID(), url: url, files: [])
        XCTAssertNotEqual(a, b)
    }

    func testFilesAreMutable() {
        var folder = WatchedFolder(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp"),
            files: []
        )
        let file = FileItem(
            id: "/tmp/a.txt",
            url: URL(fileURLWithPath: "/tmp/a.txt"),
            displayName: "a.txt",
            modificationDate: nil,
            fileSize: nil,
            typeIdentifier: nil,
            isDirectory: false
        )
        folder.files = [file]
        XCTAssertEqual(folder.files.count, 1)
    }
}

final class FileViewModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(FileViewMode.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(FileViewMode.icon.rawValue, "icon")
        XCTAssertEqual(FileViewMode.list.rawValue, "list")
        XCTAssertEqual(FileViewMode.hierarchy.rawValue, "hierarchy")
    }

    func testIDMatchesRawValue() {
        for mode in FileViewMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testInitFromRawValue() {
        XCTAssertNotNil(FileViewMode(rawValue: "icon"))
        XCTAssertNotNil(FileViewMode(rawValue: "list"))
        XCTAssertNotNil(FileViewMode(rawValue: "hierarchy"))
        XCTAssertNil(FileViewMode(rawValue: "grid"))
    }

    func testTitlesAreNonEmpty() {
        for mode in FileViewMode.allCases {
            XCTAssertFalse(mode.title.isEmpty, "\(mode) title should not be empty")
        }
    }

    func testSystemImageNamesAreNonEmpty() {
        for mode in FileViewMode.allCases {
            XCTAssertFalse(mode.systemImageName.isEmpty, "\(mode) systemImageName should not be empty")
        }
    }
}

final class SortOptionTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(SortOption.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(SortOption.name.rawValue, "name")
        XCTAssertEqual(SortOption.kind.rawValue, "kind")
        XCTAssertEqual(SortOption.dateModified.rawValue, "dateModified")
        XCTAssertEqual(SortOption.size.rawValue, "size")
    }

    func testIDMatchesRawValue() {
        for option in SortOption.allCases {
            XCTAssertEqual(option.id, option.rawValue)
        }
    }

    func testInitFromRawValue() {
        XCTAssertNotNil(SortOption(rawValue: "name"))
        XCTAssertNotNil(SortOption(rawValue: "kind"))
        XCTAssertNotNil(SortOption(rawValue: "dateModified"))
        XCTAssertNotNil(SortOption(rawValue: "size"))
        XCTAssertNil(SortOption(rawValue: "date"))
    }

    func testTitlesAreNonEmpty() {
        for option in SortOption.allCases {
            XCTAssertFalse(option.title.isEmpty, "\(option) title should not be empty")
        }
    }

    func testSystemImageNamesAreNonEmpty() {
        for option in SortOption.allCases {
            XCTAssertFalse(option.systemImageName.isEmpty, "\(option) systemImageName should not be empty")
        }
    }
}

final class SortDirectionTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(SortDirection.allCases.count, 2)
    }

    func testRawValues() {
        XCTAssertEqual(SortDirection.ascending.rawValue, "ascending")
        XCTAssertEqual(SortDirection.descending.rawValue, "descending")
    }

    func testIDMatchesRawValue() {
        for direction in SortDirection.allCases {
            XCTAssertEqual(direction.id, direction.rawValue)
        }
    }

    func testInitFromRawValue() {
        XCTAssertNotNil(SortDirection(rawValue: "ascending"))
        XCTAssertNotNil(SortDirection(rawValue: "descending"))
        XCTAssertNil(SortDirection(rawValue: "up"))
    }

    func testTitlesAreNonEmpty() {
        for direction in SortDirection.allCases {
            XCTAssertFalse(direction.title.isEmpty, "\(direction) title should not be empty")
        }
    }

    func testSystemImageNamesAreNonEmpty() {
        for direction in SortDirection.allCases {
            XCTAssertFalse(direction.systemImageName.isEmpty, "\(direction) systemImageName should not be empty")
        }
    }
}