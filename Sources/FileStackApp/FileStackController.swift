import Foundation
import os.log
import CoreGraphics

final class FileStackController: ObservableObject {
    @Published private(set) var folders: [WatchedFolder] = []
    @Published var selectedFolderID: UUID?
    @Published var selectedFileID: String?
    @Published var alertMessage: String?
    @Published var viewMode: FileViewMode
    @Published var previewScale: Double

    var selectedFolder: WatchedFolder? {
        guard let selectedFolderID else {
            return folders.first
        }
        return folders.first(where: { $0.id == selectedFolderID })
    }

    var selectedFiles: [FileItem] {
        selectedFolder?.files ?? []
    }

    var selectedFile: FileItem? {
        if let selectedFileID,
           let file = selectedFiles.first(where: { $0.id == selectedFileID }) {
            return file
        }
        return selectedFiles.first
    }

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

    func selectFile(_ file: FileItem) {
        guard selectedFileID != file.id else { return }
        selectedFileID = file.id
    }

    func setViewMode(_ mode: FileViewMode) {
        guard viewMode != mode else { return }
        viewMode = mode
        defaults.set(mode.rawValue, forKey: viewModeKey)
        updateSelectionForCurrentFolder()
        if mode == .icon {
            prefetchThumbnails(for: selectedFiles)
        }
    }

    func setPreviewScale(_ scale: Double) {
        let clamped = min(max(scale, previewScaleRange.lowerBound), previewScaleRange.upperBound)
        guard previewScale != clamped else { return }
        previewScale = clamped
        defaults.set(clamped, forKey: previewScaleKey)
        prefetchThumbnails(for: selectedFiles)
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
            selectedFolderID = preferredID
            updateSelectionForCurrentFolder()
            return
        }

        if let selectedFolderID,
           folders.contains(where: { $0.id == selectedFolderID }) {
            updateSelectionForCurrentFolder()
            return
        }

        selectedFolderID = folders.first?.id
        updateSelectionForCurrentFolder()
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
        var folder = folders[index]
        folder.files = files
        folders[index] = folder
        if folderID == selectedFolderID {
            if files.isEmpty {
                selectedFileID = nil
            } else if let currentSelection = selectedFileID,
                      files.contains(where: { $0.id == currentSelection }) == false {
                selectedFileID = files.first?.id
            } else if selectedFileID == nil {
                selectedFileID = files.first?.id
            }
        }

        prefetchThumbnails(for: folder.files)
    }

    private func saveFolders() {
        let paths = folders.map { $0.url.path }
        defaults.set(paths, forKey: pathsKey)
    }

    private func updateSelectionForCurrentFolder() {
        guard let files = selectedFolder?.files, files.isEmpty == false else {
            selectedFileID = nil
            return
        }

        if let selectedFileID,
           files.contains(where: { $0.id == selectedFileID }) {
            return
        }

        selectedFileID = files.first?.id

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
        let spacing: CGFloat = 12
        var targetWidth = 150 * previewScale
        targetWidth = min(max(targetWidth, 90), 220)

        var columnCount = Int((contentWidth + spacing) / (targetWidth + spacing))
        columnCount = max(min(columnCount, 4), 1)

        let width = (contentWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        let height = max(width * 0.75, 70)
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
