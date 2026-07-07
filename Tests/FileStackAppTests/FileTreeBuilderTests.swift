import XCTest
@testable import FileStackCore

final class FileTreeBuilderTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeBuilderTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - buildTree

    func testBuildTreeReturnsNilForNonexistentURL() {
        let bogus = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        XCTAssertNil(FileTreeBuilder.buildTree(at: bogus))
    }

    func testBuildTreeForEmptyDirectory() {
        let entry = FileTreeBuilder.buildTree(at: tempDirectory)

        XCTAssertNotNil(entry)
        XCTAssertTrue(entry!.isDirectory)
        // Empty directory: children should be nil (no children loaded)
        XCTAssertNil(entry!.children)
    }

    func testBuildTreeWithFiles() {
        createFile(named: "a.txt")
        createFile(named: "b.txt")

        let entry = FileTreeBuilder.buildTree(at: tempDirectory)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry!.children?.count, 2)
    }

    func testBuildTreeSortsDirectoriesBeforeFiles() {
        createDirectory(named: "ZFolder")
        createFile(named: "a.txt")

        let entry = FileTreeBuilder.buildTree(at: tempDirectory)
        let children = entry!.children!

        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children[0].isDirectory)
        XCTAssertFalse(children[1].isDirectory)
    }

    func testBuildTreeSortsAlphabeticallyWithinSameType() {
        createFile(named: "zebra.txt")
        createFile(named: "apple.txt")
        createFile(named: "mango.txt")

        let entry = FileTreeBuilder.buildTree(at: tempDirectory)
        let names = entry!.children!.map { $0.file.displayName }

        XCTAssertEqual(names, ["apple.txt", "mango.txt", "zebra.txt"])
    }

    func testBuildTreeRespectsDepthLimit() {
        // Create nested: tempDir/sub/deep/file.txt
        let sub = createDirectory(named: "sub")
        let deep = createDirectory(in: sub, named: "deep")
        createFile(in: deep, named: "file.txt")

        // depthLimit=1 should not recurse into sub's children
        let entry = FileTreeBuilder.buildTree(at: tempDirectory, depthLimit: 1)
        let subEntry = entry!.children?.first { $0.isDirectory }

        XCTAssertNotNil(subEntry)
        // With depthLimit=1, we get the top level only; sub's children are loaded
        // because depthRemaining starts at 1 and loadChildren decrements to 0 inside.
        // Actually, let me re-check: depthLimit=1 means depthRemaining=1 for the root's children.
        // loadChildren(of: root, depthRemaining: 1) -> iterates root's children.
        //   For each child, if directory: loadChildren(of: child, depthRemaining: 0) -> returns []
        // So sub should have nil children.
        XCTAssertNil(subEntry!.children)
    }

    func testBuildTreeRespectsChildLimit() {
        for i in 0..<10 {
            createFile(named: "file-\(i).txt")
        }

        let entry = FileTreeBuilder.buildTree(at: tempDirectory, childLimit: 3)
        XCTAssertEqual(entry!.children?.count, 3)
    }

    func testBuildTreeSkipsHiddenFiles() {
        createFile(named: ".hidden")
        createFile(named: "visible.txt")

        let entry = FileTreeBuilder.buildTree(at: tempDirectory)
        let names = entry!.children!.map { $0.file.displayName }

        XCTAssertEqual(names, ["visible.txt"])
    }

    // MARK: - FileSystemEntry

    func testFileSystemEntryID() {
        createFile(named: "test.txt")
        let entry = FileTreeBuilder.buildTree(at: tempDirectory)!
        let child = entry.children!.first!

        XCTAssertEqual(child.id, child.file.id)
    }

    func testFileSystemEntryIsDirectory() {
        createDirectory(named: "dir")
        createFile(named: "file.txt")

        let entry = FileTreeBuilder.buildTree(at: tempDirectory)!
        let dirEntry = entry.children!.first { $0.isDirectory }!
        let fileEntry = entry.children!.first { !$0.isDirectory }!

        XCTAssertTrue(dirEntry.isDirectory)
        XCTAssertFalse(fileEntry.isDirectory)
    }

    // MARK: - Helpers

    @discardableResult
    private func createFile(in directory: URL? = nil, named name: String) -> URL {
        let url = (directory ?? tempDirectory).appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("hello".utf8))
        return url
    }

    @discardableResult
    private func createDirectory(in directory: URL? = nil, named name: String) -> URL {
        let url = (directory ?? tempDirectory).appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}