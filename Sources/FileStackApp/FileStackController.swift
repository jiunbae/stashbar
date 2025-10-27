import AppKit
import CoreGraphics
import Foundation
import os.log
import ServiceManagement

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
    @Published private(set) var launchesAtLogin: Bool

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
    private let launchAtLoginKey = "LaunchAtLoginPreference"
    private let previewScaleRange: ClosedRange<Double> = 0.4...1.8
    private let cutPasteboardType = NSPasteboard.PasteboardType("com.file-stack.cut-indicator")
    private var pendingCutURLs: [URL] = []

    init() {
        if let rawValue = defaults.string(forKey: viewModeKey),
           let mode = FileViewMode(rawValue: rawValue) {
            viewMode = mode
        } else {
            viewMode = .icon
        }

        let storedScale = defaults.double(forKey: previewScaleKey)
        previewScale = previewScaleRange.contains(storedScale) ? storedScale : 1.0

        if #available(macOS 13.0, *) {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchesAtLogin = defaults.bool(forKey: launchAtLoginKey)
        }

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

    func updateSelection(ids: Set<String>, primaryID: String?) {
        let validIDs = Set(currentFiles.map { $0.id })
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

    func setLaunchAtLogin(_ enabled: Bool) {
        guard launchesAtLogin != enabled else { return }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchesAtLogin = SMAppService.mainApp.status == .enabled
                defaults.set(enabled, forKey: launchAtLoginKey)
            } catch {
                launchesAtLogin = !enabled
                alertMessage = "로그인 시 실행 설정에 실패했습니다: \(error.localizedDescription)"
                log.error("Failed to toggle login item: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            launchesAtLogin = enabled
            defaults.set(enabled, forKey: launchAtLoginKey)
        }
    }

    func copySelectedFilesToPasteboard() {
        preparePasteboardFromSelection(asCut: false)
    }

    func cutSelectedFilesToPasteboard() {
        preparePasteboardFromSelection(asCut: true)
    }

    func pasteFilesFromPasteboard() {
        guard let folder = selectedFolder else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], urls.isEmpty == false else {
            NSSound.beep()
            return
        }

        let isCutOperation = pasteboard.string(forType: cutPasteboardType) == "cut" && pendingCutURLs.isEmpty == false
        let destinationFolder = folder.url

        workerQueue.async { [weak self] in
            guard let self else { return }

            var errors: [String] = []

            for sourceURL in urls {
                let destination = self.uniqueDestinationURL(for: sourceURL, in: destinationFolder)
                do {
                    if isCutOperation {
                        try self.fileManager.moveItem(at: sourceURL, to: destination)
                    } else {
                        try self.fileManager.copyItem(at: sourceURL, to: destination)
                    }
                } catch {
                    errors.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                if errors.isEmpty == false {
                    self.alertMessage = "파일 붙여넣기에 실패했습니다:\n" + errors.joined(separator: "\n")
                    NSSound.beep()
                }
                self.pendingCutURLs = []
                pasteboard.setString("copy", forType: self.cutPasteboardType)
                self.refreshSelectedFolder()
            }
        }
    }

    func deleteSelectedFiles() {
        let files = selectedFileItems
        guard files.isEmpty == false else {
            NSSound.beep()
            return
        }

        let urls = files.map { $0.url }
        workerQueue.async { [weak self] in
            guard let self else { return }

            var errors: [String] = []
            for url in urls {
                do {
                    try self.fileManager.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                if errors.isEmpty == false {
                    self.alertMessage = "휴지통으로 이동하지 못했습니다:\n" + errors.joined(separator: "\n")
                    NSSound.beep()
                }
                self.refreshSelectedFolder()
            }
        }
    }

    private func preparePasteboardFromSelection(asCut: Bool) {
        let files = selectedFileItems
        guard files.isEmpty == false else {
            NSSound.beep()
            return
        }

        let urls = files.map { $0.url }
        pendingCutURLs = asCut ? urls : []

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
        pasteboard.setString(asCut ? "cut" : "copy", forType: cutPasteboardType)
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

    private func uniqueDestinationURL(for sourceURL: URL, in folderURL: URL) -> URL {
        var destination = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        let pathExtension = destination.pathExtension
        let baseName = destination.deletingPathExtension().lastPathComponent

        var copyIndex = 1
        while fileManager.fileExists(atPath: destination.path) {
            let suffix = copyIndex == 1 ? " copy" : " copy \(copyIndex)"
            let newName: String
            if pathExtension.isEmpty {
                newName = baseName + suffix
            } else {
                newName = baseName + suffix + "." + pathExtension
            }
            destination = folderURL.appendingPathComponent(newName)
            copyIndex += 1
        }

        return destination
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
