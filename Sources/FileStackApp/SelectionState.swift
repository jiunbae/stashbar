import AppKit
import Foundation

/// Selection state extracted from FileStackController so that selection changes do not
/// invalidate views observing the controller's other published properties (folders,
/// view mode, sort options, etc.). Only views that read selection observe this object.
final class SelectionState: ObservableObject {
    @Published private(set) var selectedFileIDs: Set<String> = []
    @Published private(set) var primarySelectedFileID: String?
    private(set) var selectionAnchorID: String?

    func handleSelection(of file: FileItem, in files: [FileItem], modifiers: NSEvent.ModifierFlags) {
        guard let fileIndex = files.firstIndex(where: { $0.id == file.id }) else { return }
        let fileID = file.id
        let anchorID = selectionAnchorID ?? primarySelectedFileID ?? fileID

        if modifiers.contains(.shift),
           let anchorIndex = files.firstIndex(where: { $0.id == anchorID }) {
            let lower = min(anchorIndex, fileIndex)
            let upper = max(anchorIndex, fileIndex)
            let rangeIDs = Set((lower...upper).map { files[$0].id })
            selectedFileIDs = rangeIDs
            primarySelectedFileID = fileID
            selectionAnchorID = anchorID
        } else if modifiers.contains(.command) {
            var updatedSelection = selectedFileIDs
            if updatedSelection.contains(fileID) {
                updatedSelection.remove(fileID)
                selectedFileIDs = updatedSelection
                if primarySelectedFileID == fileID {
                    primarySelectedFileID = files.first(where: { updatedSelection.contains($0.id) })?.id
                }
            } else {
                updatedSelection.insert(fileID)
                selectedFileIDs = updatedSelection
                primarySelectedFileID = fileID
            }
            selectionAnchorID = primarySelectedFileID
        } else {
            selectedFileIDs = [fileID]
            primarySelectedFileID = fileID
            selectionAnchorID = fileID
        }
    }

    func updateSelection(ids: Set<String>, primaryID: String?, in files: [FileItem]) {
        let validIDs = Set(files.map { $0.id })
        let filtered = ids.intersection(validIDs)
        selectedFileIDs = filtered

        if let primaryID, filtered.contains(primaryID) {
            primarySelectedFileID = primaryID
        } else {
            primarySelectedFileID = filtered.first
        }

        selectionAnchorID = primarySelectedFileID

        if filtered.isEmpty {
            primarySelectedFileID = nil
            selectionAnchorID = nil
        }
    }

    func isFileSelected(_ file: FileItem) -> Bool {
        selectedFileIDs.contains(file.id)
    }

    /// Reconcile current selection against a new file list. Drops invalid IDs and
    /// auto-promotes a primary when the previous primary disappears or none exists.
    func reconcileWithFiles(_ files: [FileItem]) {
        guard files.isEmpty == false else {
            if selectedFileIDs.isEmpty == false || primarySelectedFileID != nil {
                selectedFileIDs = []
                primarySelectedFileID = nil
                selectionAnchorID = nil
            }
            return
        }

        let validIDs = Set(files.map { $0.id })
        selectedFileIDs = selectedFileIDs.intersection(validIDs)

        if let primary = primarySelectedFileID, validIDs.contains(primary) == false {
            primarySelectedFileID = nil
        }

        if primarySelectedFileID == nil {
            if let firstSelected = files.first(where: { selectedFileIDs.contains($0.id) }) {
                primarySelectedFileID = firstSelected.id
            } else if let first = files.first {
                primarySelectedFileID = first.id
            }
        }

        if let primary = primarySelectedFileID {
            selectedFileIDs.insert(primary)
        }

        if let anchor = selectionAnchorID, validIDs.contains(anchor) == false {
            selectionAnchorID = primarySelectedFileID
        } else if selectionAnchorID == nil {
            selectionAnchorID = primarySelectedFileID
        }
    }

    func clear() {
        if selectedFileIDs.isEmpty == false || primarySelectedFileID != nil {
            selectedFileIDs = []
            primarySelectedFileID = nil
            selectionAnchorID = nil
        }
    }
}
