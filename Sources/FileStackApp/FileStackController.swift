import AppKit
import CoreGraphics
import Foundation
import os.log

final class FileStackController: ObservableObject {
    @Published private(set) var folders: [WatchedFolder] = []
    @Published var selectedFolderID: UUID? {
        didSet {
            if selectedFolderID != oldValue {
                updateSelectionForCurrentFolder()
            }
        }
    }
    @Published private(set) var selectedFileIDs: Set<String> = []
    @Published private(set) var primarySelectedFileID: String?
    @Published var alertMessage: String?
    @Published var viewMode: FileViewMode
    @Published var previewScale: Double

    var selectedFolder: WatchedFolder? {
        guard let selectedFolderID else {
            return folders.first
        }
        return folders.first(where: { $0.id == selectedFolderID })
    }

    var currentFiles: [FileItem] {
        selectedFolder?.files ?? []
    }

    var selectedFile: FileItem? {
        guard let id = primarySelectedFileID else { return nil }
        return currentFiles.first(where: { $0.id == id })
    }

    var selectedFileItems: [FileItem] {
        let ids = selectedFileIDs
        return currentFiles.filter { ids.contains($0.id) }
    }

    private var selectionAnchorID: String?

    private var watchers: [UUID: DirectoryWatcher] = [:]
    private let defaults = UserDefaults.standard
    private let pathsKey = "WatchedFolderPaths"
    private let maxItemsPerFolder = 40
    private let workerQueue = DispatchQueue(label: "com.file-stack.controller.files", qos: .userInitiated)
    private let log = Logger(subsystem: "com.file-stack.app", category: "controller")
    private let fileManager = FileManager.default
    private let viewModeKey = "ViewModePreference"
    private let previewScaleKey = "PreviewScalePreference"
    private let previewScaleRange: ClosedRange<Double> = 0.4...1.8

    init() {
        if let rawValue = defaults.string(forKey: viewModeKey),
           let mode = FileViewMode(rawValue: rawValue) {
            viewMode = mode
        } else {
            viewMode = .icon
        }

        let storedScale = defaults.double(forKey: previewScaleKey)
        previewScale = previewScaleRange.contains(storedScale) ? storedScale : 1.0

        loadPersistedFolders()
    }

    func addFolder(url: URL) {
        addFolder(url: url, persist: true)
    }

    func presentFolderSelectionPanel() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.prompt = "선택"
            panel.title = "감시할 폴더 선택"

            NSApp.activate(ignoringOtherApps: true)

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.urls.first else { return }
                self?.addFolder(url: url)
            }
        }
    }

    func removeFolder(_ folder: WatchedFolder) {
        watchers[folder.id]?.cancel()
        watchers.removeValue(forKey: folder.id)
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        ensureSelectedFolderIsValid()
    }

    func refreshSelectedFolder() {
        guard let folder = selectedFolder else { return }
        reload(folderID: folder.id)
    }

    func handleSelection(of file: FileItem, modifiers: NSEvent.ModifierFlags = []) {
        let files = currentFiles
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

        if selectedFileIDs.isEmpty {
            primarySelectedFileID = nil
            selectionAnchorID = nil
        }
    }

    func isFileSelected(_ file: FileItem) -> Bool {
        selectedFileIDs.contains(file.id)
    }

    func setViewMode(_ mode: FileViewMode) {
        guard viewMode != mode else { return }
        viewMode = mode
        defaults.set(mode.rawValue, forKey: viewModeKey)
        updateSelectionForCurrentFolder()
        if mode == .icon {
            prefetchThumbnails(for: currentFiles)
        }
    }

    func setPreviewScale(_ scale: Double) {
        let clamped = min(max(scale, previewScaleRange.lowerBound), previewScaleRange.upperBound)
        guard previewScale != clamped else { return }
        previewScale = clamped
        defaults.set(clamped, forKey: previewScaleKey)
        prefetchThumbnails(for: currentFiles)
    }

    func clearAlert() {
        alertMessage = nil
    }

    private func loadPersistedFolders() {
        let storedPaths = defaults.array(forKey: pathsKey) as? [String] ?? []
        var validURLs: [URL] = storedPaths
            .compactMap { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { directoryExists(at: $0) }

        if validURLs.isEmpty, let suggested = detectScreenshotFolder() {
            validURLs = [suggested]
        }

        for url in validURLs {
            addFolder(url: url, persist: false)
        }

        saveFolders()
        ensureSelectedFolderIsValid()
    }

    private func addFolder(url: URL, persist: Bool) {
        let standardized = url.standardizedFileURL

        guard directoryExists(at: standardized) else {
            alertMessage = "선택한 경로에 접근할 수 없습니다."
            return
        }

        guard folders.contains(where: { $0.url == standardized }) == false else {
            alertMessage = "이미 추가된 폴더입니다."
            return
        }

        let folder = WatchedFolder(id: UUID(), url: standardized, files: [])
        folders.append(folder)
        ensureSelectedFolderIsValid(with: folder.id)
        startWatcher(for: folder)
        reload(folderID: folder.id)

        if persist {
            saveFolders()
        }
    }

    private func ensureSelectedFolderIsValid(with preferredID: UUID? = nil) {
        if let preferredID {
            if selectedFolderID != preferredID {
                selectedFolderID = preferredID
            } else {
                updateSelectionForCurrentFolder()
            }
            return
        }

        if let currentID = selectedFolderID,
           folders.contains(where: { $0.id == currentID }) {
            updateSelectionForCurrentFolder()
            return
        }

        let newID = folders.first?.id
        if selectedFolderID != newID {
            selectedFolderID = newID
        } else {
            updateSelectionForCurrentFolder()
        }
    }

    private func startWatcher(for folder: WatchedFolder) {
        do {
            let watcher = try DirectoryWatcher(url: folder.url) { [weak self] in
                self?.reload(folderID: folder.id)
            }
            watchers[folder.id] = watcher
        } catch DirectoryWatcher.WatcherError.failedToOpen(let errnoValue) {
            alertMessage = "폴더 감시에 실패했습니다. (errno: \(errnoValue))"
        } catch {
            alertMessage = "폴더 감시에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func reload(folderID: UUID) {
        guard let folder = folders.first(where: { $0.id == folderID }) else { return }
        let folderURL = folder.url
        let limit = maxItemsPerFolder

        workerQueue.async { [weak self] in
            let files = FileStackController.loadFiles(at: folderURL, limit: limit)
            DispatchQueue.main.async {
                guard let self else { return }
                self.apply(files: files, to: folderID)
            }
        }
    }

    private func apply(files: [FileItem], to folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].files = files
        if folderID == selectedFolderID {
            updateSelectionForCurrentFolder()
        } else if viewMode == .icon {
            prefetchThumbnails(for: files)
        }
    }

    private func saveFolders() {
        let paths = folders.map { $0.url.path }
        defaults.set(paths, forKey: pathsKey)
    }

    private func updateSelectionForCurrentFolder() {
        guard let files = selectedFolder?.files, files.isEmpty == false else {
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

        if selectedFileIDs.isEmpty {
            if let primary = primarySelectedFileID, validIDs.contains(primary) {
                selectedFileIDs = [primary]
            } else if let first = files.first {
                selectedFileIDs = [first.id]
                primarySelectedFileID = first.id
            }
        }

        if primarySelectedFileID == nil {
            if let firstSelected = files.first(where: { selectedFileIDs.contains($0.id) }) {
                primarySelectedFileID = firstSelected.id
            } else if let first = files.first {
                selectedFileIDs = [first.id]
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

        prefetchThumbnails(for: files)
    }

    private func prefetchThumbnails(for files: [FileItem]) {
        guard viewMode == .icon else { return }
        let size = tileSizeForCurrentScale()
        let urls = files.prefix(20).map { $0.url }
        ThumbnailCache.shared.prefetch(urls: urls, size: size)
    }

    private func tileSizeForCurrentScale() -> CGSize {
        let contentWidth: CGFloat = 360 - 32
        let spacing: CGFloat = 10
        let maxColumns = 5
        var targetWidth = 150 * previewScale
        targetWidth = min(max(targetWidth, 50), 200)

        var columnCount = Int((contentWidth + spacing) / (targetWidth + spacing))
        columnCount = max(1, min(maxColumns, columnCount))

        let width = (contentWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        let height = max(width * 0.75, 60)
        return CGSize(width: width, height: height)
    }

    private func detectScreenshotFolder() -> URL? {
        if let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           location.isEmpty == false {
            let url = URL(fileURLWithPath: location).standardizedFileURL
            if directoryExists(at: url) {
                return url
            }
        }

        let picturesScreenshots = fileManager.urls(for: .picturesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Screenshots", isDirectory: true)
        if let picturesScreenshots, directoryExists(at: picturesScreenshots) {
            return picturesScreenshots
        }

        if let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktop
        }

        return nil
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func loadFiles(at folderURL: URL, limit: Int) -> [FileItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .localizedNameKey,
            .contentModificationDateKey,
            .typeIdentifierKey,
            .fileSizeKey,
            .isDirectoryKey
        ]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let entries: [(URL, URLResourceValues)] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
                return nil
            }
            return (url, values)
        }

        let sorted = entries.sorted { lhs, rhs in
            let lhsDate = lhs.1.contentModificationDate ?? .distantPast
            let rhsDate = rhs.1.contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        return sorted.prefix(limit).map { entry in
            FileItem(url: entry.0, values: entry.1)
        }
    }
}
