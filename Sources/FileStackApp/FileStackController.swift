import AppKit
import CoreGraphics
import FileStackCore
import Foundation
import os.log
import ServiceManagement

final class FileStackController: ObservableObject {
    @Published private(set) var folders: [WatchedFolder] = []
    @Published var selectedFolderID: UUID? {
        didSet {
            if selectedFolderID != oldValue {
                refreshCurrentFilesCache()
                selectionState.reconcileWithFiles(cachedCurrentFiles)
                if viewMode == .icon, isInterfaceActive {
                    prefetchThumbnails(for: currentFiles)
                }
            }
        }
    }
    /// Selection state lives on its own ObservableObject so that selection changes do not
    /// invalidate the entire ContentView body — only views that observe `selectionState` rebuild.
    let selectionState = SelectionState()

    @Published var alertMessage: String?
    @Published var viewMode: FileViewMode
    @Published var previewScale: Double
    @Published var sortOption: SortOption
    @Published var sortDirection: SortDirection
    @Published var searchText: String = ""
    @Published private(set) var launchesAtLogin: Bool

    /// Monotonic counter incremented whenever the file list of any watched folder changes.
    /// Cheaper than hashing `currentFiles` for downstream change detection (e.g. QuickLook refresh).
    @Published private(set) var fileListGeneration: Int = 0

    var selectedFolder: WatchedFolder? {
        guard let selectedFolderID else {
            return folders.first
        }
        return folders.first(where: { $0.id == selectedFolderID })
    }

    var currentFiles: [FileItem] {
        if searchText.isEmpty {
            return cachedCurrentFiles
        }
        return cachedCurrentFiles.filter {
            $0.displayName.localizedStandardContains(searchText)
        }
    }

    private var cachedCurrentFiles: [FileItem] = []

    var selectedFile: FileItem? {
        guard let id = selectionState.primarySelectedFileID else { return nil }
        return currentFiles.first(where: { $0.id == id })
    }

    var selectedFileItems: [FileItem] {
        let ids = selectionState.selectedFileIDs
        return currentFiles.filter { ids.contains($0.id) }
    }

    private var watchers: [UUID: DirectoryWatcher] = [:]
    private let defaults = UserDefaults.standard
    private let pathsKey = "WatchedFolderPaths"               // legacy, kept for migration
    private let bookmarksKey = "WatchedFolderBookmarks_v1"     // security-scoped bookmark data
    /// URLs whose security-scoped resource we explicitly started (resolved-from-bookmark
    /// URLs require a balanced stop on removal; URLs from NSOpenPanel have implicit
    /// access for the current session and are not tracked here).
    private var securityScopedURLs: [UUID: URL] = [:]
    private static let maxItemsKey = "MaxItemsPerFolderPreference"
    private let maxItemsPerFolderRange: ClosedRange<Int> = 10...200
    @Published var maxItemsPerFolder: Int
    private let workerQueue = DispatchQueue(label: "com.file-stack.controller.files", qos: .userInitiated)
    private let log = Logger(subsystem: "com.file-stack.app", category: "controller")
    private let fileManager = FileManager.default
    private let viewModeKey = "ViewModePreference"
    private let previewScaleKey = "PreviewScalePreference"
    private let sortOptionKey = "SortOptionPreference"
    private let sortDirectionKey = "SortDirectionPreference"
    private let launchAtLoginKey = "LaunchAtLoginPreference"
    private let favoriteFolderPathsKey = "FavoriteFolderPaths_v1"
    private var favoriteFolderPaths: Set<String> = []
    private let previewScaleRange: ClosedRange<Double> = 0.4...1.8
    private let cutPasteboardType = NSPasteboard.PasteboardType("com.file-stack.cut-indicator")
    private var pendingCutURLs: [URL] = []
    private var isInterfaceActive = false
    private var pendingReloadFolderIDs: Set<UUID> = []

    init(loadPersistedState: Bool = true) {
        if let rawValue = defaults.string(forKey: viewModeKey),
           let mode = FileViewMode(rawValue: rawValue) {
            viewMode = mode
        } else {
            viewMode = .icon
        }

        let storedScale = defaults.double(forKey: previewScaleKey)
        previewScale = previewScaleRange.contains(storedScale) ? storedScale : 1.0

        sortOption = defaults.string(forKey: sortOptionKey).flatMap(SortOption.init) ?? .dateModified
        sortDirection = defaults.string(forKey: sortDirectionKey).flatMap(SortDirection.init) ?? .descending

        if #available(macOS 13.0, *) {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchesAtLogin = defaults.bool(forKey: launchAtLoginKey)
        }

        let storedMaxItems = defaults.integer(forKey: Self.maxItemsKey)
        maxItemsPerFolder = storedMaxItems > 0 ? min(max(storedMaxItems, 10), 200) : 40

        if loadPersistedState {
            loadFavorites()
            loadPersistedFolders()
        }
    }

    deinit {
        for watcher in watchers.values {
            watcher.cancel()
        }
        for url in securityScopedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func addFolder(url: URL) {
        addFolder(url: url, persist: true)
    }

    func presentFolderSelectionPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = NSLocalizedString("panel.select", comment: "NSOpenPanel select button")
        panel.title = NSLocalizedString("panel.selectFolder", comment: "NSOpenPanel title")

        NSApp.activate(ignoringOtherApps: true)

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.urls.first else { return }
            self?.addFolder(url: url)
        }
    }

    func removeFolder(_ folder: WatchedFolder) {
        watchers[folder.id]?.cancel()
        watchers.removeValue(forKey: folder.id)
        if let url = securityScopedURLs.removeValue(forKey: folder.id) {
            url.stopAccessingSecurityScopedResource()
        }
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        ensureSelectedFolderIsValid()
    }

    func toggleFavorite(_ folder: WatchedFolder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let newValue = !folders[index].isFavorite
        folders[index].isFavorite = newValue
        if newValue {
            favoriteFolderPaths.insert(folder.url.path)
        } else {
            favoriteFolderPaths.remove(folder.url.path)
        }
        saveFavorites()
        sortFolders()
    }

    func refreshSelectedFolder() {
        guard let folder = selectedFolder else { return }
        reload(folderID: folder.id)
    }

    func handleSelection(of file: FileItem, modifiers: NSEvent.ModifierFlags = []) {
        selectionState.handleSelection(of: file, in: currentFiles, modifiers: modifiers)
    }

    func updateSelection(ids: Set<String>, primaryID: String?) {
        selectionState.updateSelection(ids: ids, primaryID: primaryID, in: currentFiles)
    }

    func isFileSelected(_ file: FileItem) -> Bool {
        selectionState.isFileSelected(file)
    }

    func setViewMode(_ mode: FileViewMode) {
        guard viewMode != mode else { return }
        viewMode = mode
        defaults.set(mode.rawValue, forKey: viewModeKey)
        reconcileSelectionWithCurrentFolder()
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

    func setSortOption(_ option: SortOption) {
        guard sortOption != option else { return }
        sortOption = option
        defaults.set(option.rawValue, forKey: sortOptionKey)
        refreshSelectedFolder()
    }

    func setSortDirection(_ direction: SortDirection) {
        guard sortDirection != direction else { return }
        sortDirection = direction
        defaults.set(direction.rawValue, forKey: sortDirectionKey)
        refreshSelectedFolder()
    }

    func setSearchText(_ text: String) {
        guard searchText != text else { return }
        searchText = text
        selectionState.reconcileWithFiles(currentFiles)
        if viewMode == .icon, isInterfaceActive {
            prefetchThumbnails(for: currentFiles)
        }
    }

    func setMaxItemsPerFolder(_ count: Int) {
        let clamped = min(max(count, maxItemsPerFolderRange.lowerBound), maxItemsPerFolderRange.upperBound)
        guard maxItemsPerFolder != clamped else { return }
        maxItemsPerFolder = clamped
        defaults.set(clamped, forKey: Self.maxItemsKey)
        refreshSelectedFolder()
    }

    func setInterfaceActive(_ active: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isInterfaceActive != active else { return }
        isInterfaceActive = active
        if active {
            processPendingReloads()
            prefetchThumbnails(for: currentFiles)
        }
    }

    func clearAlert() {
        alertMessage = nil
    }

    func configurePreview(
        folders urls: [URL],
        selectedFolderURL: URL,
        viewMode: FileViewMode,
        previewScale: Double,
        sortOption: SortOption,
        sortDirection: SortDirection,
        selectedDisplayNames: [String]
    ) {
        for watcher in watchers.values {
            watcher.cancel()
        }
        watchers.removeAll()

        for url in securityScopedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll()

        pendingReloadFolderIDs.removeAll()
        alertMessage = nil

        self.viewMode = viewMode
        self.previewScale = min(max(previewScale, previewScaleRange.lowerBound), previewScaleRange.upperBound)
        self.sortOption = sortOption
        self.sortDirection = sortDirection

        let normalizedSelectedURL = selectedFolderURL.standardizedFileURL
        folders = urls.compactMap { url in
            let normalizedURL = url.standardizedFileURL
            guard directoryExists(at: normalizedURL) else { return nil }
            let files = Self.loadFiles(
                at: normalizedURL,
                limit: maxItemsPerFolder,
                sortOption: sortOption,
                sortDirection: sortDirection
            )
            return WatchedFolder(id: UUID(), url: normalizedURL, files: files, isFavorite: favoriteFolderPaths.contains(normalizedURL.path))
        }
        sortFolders()

        selectedFolderID = folders.first(where: { $0.url == normalizedSelectedURL })?.id ?? folders.first?.id
        refreshCurrentFilesCache()

        let selectedIDs = Set(
            currentFiles
                .filter { selectedDisplayNames.contains($0.displayName) }
                .map(\.id)
        )
        let primaryID = currentFiles.first { selectedDisplayNames.contains($0.displayName) }?.id
        selectionState.updateSelection(ids: selectedIDs, primaryID: primaryID, in: currentFiles)

        fileListGeneration &+= 1
        isInterfaceActive = true

        if viewMode == .icon {
            prefetchThumbnails(for: currentFiles)
        }
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
                alertMessage = String(format: NSLocalizedString("error.loginItem", comment: "Login item registration error"), error.localizedDescription)
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

        let capturedCutURLs = pendingCutURLs
        pendingCutURLs = []
        let isCutOperation = pasteboard.string(forType: cutPasteboardType) == "cut" && !capturedCutURLs.isEmpty
        let destinationFolder = folder.url

        workerQueue.async { [weak self] in
            guard let self else { return }

            var errors: [String] = []

            for sourceURL in urls {
                guard self.fileManager.fileExists(atPath: sourceURL.path) else {
                    errors.append(String(format: NSLocalizedString("error.fileNotFound", comment: "File not found error"), sourceURL.lastPathComponent))
                    continue
                }
                do {
                    let destination = try self.uniqueDestinationURL(for: sourceURL, in: destinationFolder)
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
                    self.alertMessage = String(format: NSLocalizedString("error.pasteFailed", comment: "Paste failed error"), errors.joined(separator: "\n"))
                    NSSound.beep()
                }
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
                    self.alertMessage = String(format: NSLocalizedString("error.trashFailed", comment: "Trash failed error"), errors.joined(separator: "\n"))
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
        migrateLegacyPathsIfNeeded()

        let storedBookmarks = (defaults.array(forKey: bookmarksKey) as? [Data]) ?? []
        var staleBookmarkNames: [String] = []

        for data in storedBookmarks {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }

            if stale {
                staleBookmarkNames.append(url.lastPathComponent)
            }

            let beforeCount = folders.count
            addFolder(url: url, persist: false, suppressAlert: true)
            if folders.count > beforeCount, let addedID = folders.last?.id {
                securityScopedURLs[addedID] = url
            } else {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if staleBookmarkNames.isEmpty == false {
            let list = staleBookmarkNames.map { "- \($0)" }.joined(separator: "\n")
            alertMessage = String(format: NSLocalizedString("error.staleBookmarks", comment: "Stale bookmark error"), list)
        }

        if folders.isEmpty, let suggested = detectScreenshotFolder() {
            addFolder(url: suggested, persist: false, suppressAlert: true)
        }

        saveFolders()
        ensureSelectedFolderIsValid()
    }

    /// One-shot upgrade from the pre-sandbox path-only persistence format. In a sandbox
    /// build the legacy paths usually become inaccessible (no bookmark data), so the
    /// resulting bookmark list may be empty — that's expected; the user will re-add
    /// folders through NSOpenPanel and we then have proper security scopes.
    private func migrateLegacyPathsIfNeeded() {
        guard defaults.object(forKey: bookmarksKey) == nil else { return }
        let legacyPaths = defaults.array(forKey: pathsKey) as? [String] ?? []
        guard legacyPaths.isEmpty == false else { return }

        let bookmarks: [Data] = legacyPaths.compactMap { path in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard directoryExists(at: url) else { return nil }
            return try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        defaults.set(bookmarks, forKey: bookmarksKey)
        defaults.removeObject(forKey: pathsKey)
    }

    private func addFolder(url: URL, persist: Bool, suppressAlert: Bool = false) {
        let standardized = url.standardizedFileURL

        guard directoryExists(at: standardized) else {
            if !suppressAlert {
                alertMessage = NSLocalizedString("error.pathInaccessible", comment: "Path inaccessible error")
            }
            return
        }

        guard folders.contains(where: { $0.url == standardized }) == false else {
            if !suppressAlert {
                alertMessage = NSLocalizedString("error.duplicateFolder", comment: "Duplicate folder error")
            }
            return
        }

        let folder = WatchedFolder(id: UUID(), url: standardized, files: [], isFavorite: favoriteFolderPaths.contains(standardized.path))
        folders.append(folder)
        sortFolders()
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
                refreshCurrentFilesCache()
                reconcileSelectionWithCurrentFolder()
            }
            return
        }

        if let currentID = selectedFolderID,
           folders.contains(where: { $0.id == currentID }) {
            refreshCurrentFilesCache()
            reconcileSelectionWithCurrentFolder()
            return
        }

        let newID = folders.first?.id
        if selectedFolderID != newID {
            selectedFolderID = newID
        } else {
            refreshCurrentFilesCache()
            reconcileSelectionWithCurrentFolder()
        }
    }

    private func startWatcher(for folder: WatchedFolder) {
        do {
            let watcher = try DirectoryWatcher(url: folder.url) { [weak self] in
                self?.reload(folderID: folder.id)
            }
            watchers[folder.id] = watcher
        } catch DirectoryWatcher.WatcherError.failedToCreateStream {
            alertMessage = NSLocalizedString("error.watcherCreateFailed", comment: "Watcher stream creation error")
        } catch DirectoryWatcher.WatcherError.failedToStartStream {
            alertMessage = NSLocalizedString("error.watcherStartFailed", comment: "Watcher stream start error")
        } catch {
            alertMessage = String(format: NSLocalizedString("error.watcherFailed", comment: "Watcher failed error"), error.localizedDescription)
        }
    }

    private func reload(folderID: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
        if isInterfaceActive == false {
            pendingReloadFolderIDs.insert(folderID)
            return
        }
        pendingReloadFolderIDs.remove(folderID)
        performReload(folderID: folderID)
    }

    private func performReload(folderID: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let folder = folders.first(where: { $0.id == folderID }) else { return }
        let folderURL = folder.url
        let limit = maxItemsPerFolder
        let option = sortOption
        let direction = sortDirection

        workerQueue.async { [weak self] in
            let files = FileStackController.loadFiles(at: folderURL, limit: limit, sortOption: option, sortDirection: direction)
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isInterfaceActive else {
                    self.pendingReloadFolderIDs.insert(folderID)
                    return
                }
                self.apply(files: files, to: folderID)
            }
        }
    }

    private func apply(files: [FileItem], to folderID: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }

        let oldFiles = folders[index].files
        guard oldFiles != files else { return }   // skip @Published fire entirely
        folders[index].files = files
        fileListGeneration &+= 1

        if folderID == selectedFolderID {
            refreshCurrentFilesCache()
            reconcileSelectionWithCurrentFolder()
        }

        if viewMode == .icon {
            prefetchThumbnails(for: files)
        }
    }

    private func saveFolders() {
        let bookmarks: [Data] = folders.compactMap { folder in
            try? folder.url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        defaults.set(bookmarks, forKey: bookmarksKey)
    }

    private func loadFavorites() {
        let paths = defaults.stringArray(forKey: favoriteFolderPathsKey) ?? []
        favoriteFolderPaths = Set(paths)
    }

    private func saveFavorites() {
        defaults.set(Array(favoriteFolderPaths), forKey: favoriteFolderPathsKey)
    }

    private func sortFolders() {
        var favorites: [WatchedFolder] = []
        var others: [WatchedFolder] = []
        for folder in folders {
            if folder.isFavorite {
                favorites.append(folder)
            } else {
                others.append(folder)
            }
        }
        folders = favorites + others
    }

    private func refreshCurrentFilesCache() {
        cachedCurrentFiles = selectedFolder?.files ?? []
    }

    private func reconcileSelectionWithCurrentFolder() {
        selectionState.reconcileWithFiles(cachedCurrentFiles)
    }

    private func prefetchThumbnails(for files: [FileItem]) {
        guard viewMode == .icon, isInterfaceActive else { return }
        // Cache is keyed by URL only (size doesn't affect hit/miss). Prefetch ALL files
        // so off-screen items have thumbnails ready by the time scrolling reveals them.
        // The file list is already capped at maxItemsPerFolder, so this is bounded work.
        let size = CGSize(width: 120, height: 90)
        let entries = files.map { (url: $0.url, sourceModified: $0.modificationDate) }
        ThumbnailCache.shared.prefetch(urls: entries, size: size)
    }

    private func processPendingReloads() {
        guard isInterfaceActive else { return }

        let idsToReload: [UUID]
        if pendingReloadFolderIDs.isEmpty {
            if let selectedID = selectedFolder?.id {
                idsToReload = [selectedID]
            } else {
                idsToReload = []
            }
        } else {
            idsToReload = Array(pendingReloadFolderIDs)
        }
        pendingReloadFolderIDs.removeAll()

        for id in idsToReload {
            performReload(folderID: id)
        }
    }

    private func uniqueDestinationURL(for sourceURL: URL, in folderURL: URL) throws -> URL {
        var destination = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        let pathExtension = destination.pathExtension
        let baseName = destination.deletingPathExtension().lastPathComponent

        var copyIndex = 1
        let maxAttempts = 10000
        while fileManager.fileExists(atPath: destination.path) {
            guard copyIndex <= maxAttempts else {
                throw NSError(domain: "FileStackController", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("error.uniqueFilenameFailed", comment: "Unique filename generation error")
                ])
            }
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

    /// Returns a sensible default screenshot folder for first-run bootstrap.
    /// Returns nil if no dedicated screenshot folder exists — we deliberately do NOT
    /// fall back to ~/Desktop because that would silently watch the user's entire
    /// desktop, which is rarely what they want.
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

        return nil
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func loadFiles(at folderURL: URL, limit: Int, sortOption: SortOption, sortDirection: SortDirection) -> [FileItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .localizedNameKey,
            .contentModificationDateKey,
            .typeIdentifierKey,
            .fileSizeKey,
            .isDirectoryKey,
            .tagNamesKey
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
            let ascending = sortDirection == .ascending

            switch sortOption {
            case .name:
                let lhsName = lhs.1.localizedName ?? lhs.0.lastPathComponent
                let rhsName = rhs.1.localizedName ?? rhs.0.lastPathComponent
                let comparison = lhsName.localizedStandardCompare(rhsName)
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending

            case .dateModified:
                let lhsDate = lhs.1.contentModificationDate ?? .distantPast
                let rhsDate = rhs.1.contentModificationDate ?? .distantPast
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate

            case .size:
                let lhsSize = lhs.1.fileSize ?? 0
                let rhsSize = rhs.1.fileSize ?? 0
                return ascending ? lhsSize < rhsSize : lhsSize > rhsSize

            case .kind:
                let lhsIsDir = lhs.1.isDirectory ?? false
                let rhsIsDir = rhs.1.isDirectory ?? false

                if lhsIsDir != rhsIsDir {
                    return lhsIsDir
                }

                let lhsType = lhs.1.typeIdentifier ?? ""
                let rhsType = rhs.1.typeIdentifier ?? ""
                let comparison = lhsType.localizedStandardCompare(rhsType)
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
        }

        return sorted.prefix(limit).map { entry in
            FileItem(url: entry.0, values: entry.1)
        }
    }
}
