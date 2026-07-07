import XCTest
import AppKit
@testable import FileStackCore

final class SelectionStateTests: XCTestCase {

    private var state: SelectionState!
    private var files: [FileItem]!

    override func setUp() {
        super.setUp()
        state = SelectionState()
        files = (0..<5).map { i in
            FileItem(
                id: "file-\(i)",
                url: URL(fileURLWithPath: "/tmp/file-\(i)"),
                displayName: "file-\(i)",
                modificationDate: nil,
                fileSize: Int64(i * 100),
                typeIdentifier: "public.data",
                isDirectory: false
            )
        }
    }

    override func tearDown() {
        state = nil
        files = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsEmpty() {
        XCTAssertTrue(state.selectedFileIDs.isEmpty)
        XCTAssertNil(state.primarySelectedFileID)
        XCTAssertNil(state.selectionAnchorID)
    }

    // MARK: - Plain click (no modifiers)

    func testPlainClickSelectsSingleFile() {
        state.handleSelection(of: files[2], in: files, modifiers: [])

        XCTAssertEqual(state.selectedFileIDs, ["file-2"])
        XCTAssertEqual(state.primarySelectedFileID, "file-2")
        XCTAssertEqual(state.selectionAnchorID, "file-2")
    }

    func testPlainClickReplacesPreviousSelection() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[3], in: files, modifiers: [])

        XCTAssertEqual(state.selectedFileIDs, ["file-3"])
        XCTAssertEqual(state.primarySelectedFileID, "file-3")
    }

    // MARK: - Command-click (toggle)

    func testCommandClickAddsToSelection() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[2], in: files, modifiers: .command)

        XCTAssertEqual(state.selectedFileIDs, ["file-0", "file-2"])
        XCTAssertEqual(state.primarySelectedFileID, "file-2")
    }

    func testCommandClickRemovesFromSelection() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[2], in: files, modifiers: .command)
        state.handleSelection(of: files[0], in: files, modifiers: .command)

        XCTAssertEqual(state.selectedFileIDs, ["file-2"])
        XCTAssertEqual(state.primarySelectedFileID, "file-2")
    }

    func testCommandClickRemovingPrimaryPromotesNext() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[1], in: files, modifiers: .command)
        // Primary is file-1. Remove it.
        state.handleSelection(of: files[1], in: files, modifiers: .command)

        XCTAssertEqual(state.selectedFileIDs, ["file-0"])
        XCTAssertEqual(state.primarySelectedFileID, "file-0")
    }

    // MARK: - Shift-click (range)

    func testShiftClickSelectsRange() {
        state.handleSelection(of: files[1], in: files, modifiers: [])
        state.handleSelection(of: files[3], in: files, modifiers: .shift)

        XCTAssertEqual(state.selectedFileIDs, ["file-1", "file-2", "file-3"])
        XCTAssertEqual(state.primarySelectedFileID, "file-3")
    }

    func testShiftClickBackwardRange() {
        state.handleSelection(of: files[3], in: files, modifiers: [])
        state.handleSelection(of: files[1], in: files, modifiers: .shift)

        XCTAssertEqual(state.selectedFileIDs, ["file-1", "file-2", "file-3"])
        XCTAssertEqual(state.primarySelectedFileID, "file-1")
    }

    func testShiftClickUsesAnchor() {
        // First click sets anchor at file-1
        state.handleSelection(of: files[1], in: files, modifiers: [])
        // Shift-click file-3: selects range anchor(1)...3
        state.handleSelection(of: files[3], in: files, modifiers: .shift)
        XCTAssertEqual(state.selectedFileIDs, ["file-1", "file-2", "file-3"])

        // Shift-click file-0: selects range anchor(1)...0, i.e. 0...1
        // The anchor stays at file-1 from the original click
        state.handleSelection(of: files[0], in: files, modifiers: .shift)
        XCTAssertEqual(state.selectedFileIDs, ["file-0", "file-1"])
        XCTAssertEqual(state.primarySelectedFileID, "file-0")
    }

    // MARK: - handleSelection edge cases

    func testHandleSelectionWithFileNotInListIsNoOp() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        let foreign = FileItem(
            id: "foreign",
            url: URL(fileURLWithPath: "/other"),
            displayName: "other",
            modificationDate: nil,
            fileSize: nil,
            typeIdentifier: nil,
            isDirectory: false
        )
        state.handleSelection(of: foreign, in: files, modifiers: [])

        // Should remain unchanged
        XCTAssertEqual(state.selectedFileIDs, ["file-0"])
    }

    // MARK: - isFileSelected

    func testIsFileSelected() {
        state.handleSelection(of: files[2], in: files, modifiers: [])
        XCTAssertTrue(state.isFileSelected(files[2]))
        XCTAssertFalse(state.isFileSelected(files[0]))
    }

    // MARK: - updateSelection

    func testUpdateSelection() {
        state.updateSelection(ids: ["file-0", "file-2"], primaryID: "file-2", in: files)

        XCTAssertEqual(state.selectedFileIDs, ["file-0", "file-2"])
        XCTAssertEqual(state.primarySelectedFileID, "file-2")
        XCTAssertEqual(state.selectionAnchorID, "file-2")
    }

    func testUpdateSelectionFiltersInvalidIDs() {
        state.updateSelection(ids: ["file-0", "nonexistent"], primaryID: "file-0", in: files)

        XCTAssertEqual(state.selectedFileIDs, ["file-0"])
        XCTAssertEqual(state.primarySelectedFileID, "file-0")
    }

    func testUpdateSelectionWithInvalidPrimaryPicksFirst() {
        state.updateSelection(ids: ["file-0", "file-1"], primaryID: "nonexistent", in: files)

        XCTAssertNotNil(state.primarySelectedFileID)
        XCTAssertTrue(state.selectedFileIDs.contains(state.primarySelectedFileID!))
    }

    func testUpdateSelectionWithEmptySetClearsAll() {
        state.updateSelection(ids: [], primaryID: nil, in: files)

        XCTAssertTrue(state.selectedFileIDs.isEmpty)
        XCTAssertNil(state.primarySelectedFileID)
        XCTAssertNil(state.selectionAnchorID)
    }

    // MARK: - reconcileWithFiles

    func testReconcileWithFilesDropsInvalidIDs() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[2], in: files, modifiers: .command)

        // Remove file-0 from the file list
        let remaining = Array(files.dropFirst())
        state.reconcileWithFiles(remaining)

        XCTAssertFalse(state.selectedFileIDs.contains("file-0"))
        XCTAssertTrue(state.selectedFileIDs.contains("file-2"))
    }

    func testReconcileWithFilesPromotesPrimaryWhenPrimaryDisappears() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[2], in: files, modifiers: .command)
        // Primary is file-2

        // Remove file-2
        let remaining = files.filter { $0.id != "file-2" }
        state.reconcileWithFiles(remaining)

        XCTAssertNotEqual(state.primarySelectedFileID, "file-2")
        XCTAssertNotNil(state.primarySelectedFileID)
    }

    func testReconcileWithFilesAutoSelectsFirstWhenNoneSelected() {
        state.reconcileWithFiles(files)

        XCTAssertEqual(state.primarySelectedFileID, files.first?.id)
        XCTAssertTrue(state.selectedFileIDs.contains(files.first!.id))
    }

    func testReconcileWithFilesEmptyListClearsAll() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.reconcileWithFiles([])

        XCTAssertTrue(state.selectedFileIDs.isEmpty)
        XCTAssertNil(state.primarySelectedFileID)
        XCTAssertNil(state.selectionAnchorID)
    }

    func testReconcileWithFilesEmptyListWhenAlreadyEmptyIsNoOp() {
        state.reconcileWithFiles([])
        XCTAssertTrue(state.selectedFileIDs.isEmpty)
        XCTAssertNil(state.primarySelectedFileID)
    }

    // MARK: - clear

    func testClear() {
        state.handleSelection(of: files[0], in: files, modifiers: [])
        state.handleSelection(of: files[2], in: files, modifiers: .command)
        state.clear()

        XCTAssertTrue(state.selectedFileIDs.isEmpty)
        XCTAssertNil(state.primarySelectedFileID)
        XCTAssertNil(state.selectionAnchorID)
    }

    func testClearWhenAlreadyEmptyIsNoOp() {
        state.clear()
        XCTAssertTrue(state.selectedFileIDs.isEmpty)
    }
}