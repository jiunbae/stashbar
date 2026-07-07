import AppKit
import FileStackCore
import QuartzCore
import SwiftUI

private protocol IconCollectionCommandHandling: AnyObject {
    func handleCommandKey(_ event: NSEvent) -> Bool
}

private final class FileCollectionView: NSCollectionView {
    weak var commandHandler: IconCollectionCommandHandling?
    var doubleClickHandler: ((NSPoint) -> Void)?

    override func keyDown(with event: NSEvent) {
        if commandHandler?.handleCommandKey(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    /// Accept the first click even when the popover window is not yet key. Without this,
    /// the very first click after the popover opens is consumed for window activation
    /// instead of being delivered as a selection event, causing a perceived ~1s delay.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// Detect double-clicks via the event's clickCount instead of attaching an
    /// NSClickGestureRecognizer with numberOfClicksRequired = 2. The recognizer
    /// approach delays single-click delivery for the system double-click interval
    /// (~250ms) while it disambiguates, which made selection feedback feel laggy.
    /// Doing it on mouseDown lets the first click fall through to NSCollectionView's
    /// default selection handling immediately while still catching the second click
    /// as a double-click.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            doubleClickHandler?(point)
            return
        }
        super.mouseDown(with: event)
    }
}

struct IconCollectionViewRepresentable: NSViewRepresentable {
    let controller: FileStackController
    let selectedFileIDs: Set<String>
    let primarySelectedFileID: String?
    /// Stored as an explicit struct property so SwiftUI invokes updateNSView when the
    /// slider moves. Reading the value off the controller alone wasn't enough — the
    /// representable struct looked unchanged and SwiftUI elided the update call.
    let previewScale: Double
    /// Same reason as `previewScale`: when a watched file is added/removed the controller
    /// mutates its file list but none of this representable's other stored properties change,
    /// so SwiftUI would elide updateNSView and the grid wouldn't reflect the new file until a
    /// view-mode switch forced makeNSView. Threading the controller's monotonic generation
    /// counter through here makes the struct compare unequal, so updateNSView runs and picks
    /// up the new `controller.currentFiles`.
    let fileListGeneration: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

        let collectionView = FileCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(IconCollectionItem.self, forItemWithIdentifier: IconCollectionItem.reuseIdentifier)
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)

        collectionView.commandHandler = context.coordinator
        collectionView.doubleClickHandler = { [weak coordinator = context.coordinator] point in
            coordinator?.handleDoubleClick(at: point)
        }
        context.coordinator.collectionView = collectionView

        scrollView.documentView = collectionView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let collectionView = context.coordinator.collectionView,
              let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else {
            return
        }

        context.coordinator.cachedSelectedIDs = selectedFileIDs
        context.coordinator.cachedPrimaryID = primarySelectedFileID

        _ = context.coordinator.layoutMetrics(for: collectionView)
        let needsLayout = context.coordinator.applyUpdates(with: controller.currentFiles)
        context.coordinator.applySelection()

        if needsLayout {
            layout.invalidateLayout()
        }
    }

    final class Coordinator: NSObject, IconCollectionCommandHandling, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
        let controller: FileStackController
        var collectionView: NSCollectionView?
        private var files: [FileItem] = []
        private var fileIDToIndex: [String: Int] = [:]
        private var suppressSelectionUpdates = false
        private var lastUserSelectionIndexPath: IndexPath?
        private var lastKnownScale: Double
        private var currentMetrics = IconCollectionLayoutMetrics(
            itemSize: NSSize(width: 140, height: 180),
            thumbnailSize: NSSize(width: 120, height: 120)
        )
        private var skipNextSelectionSync = false

        // Latest selection values pushed in via updateNSView. Keeping them here lets the
        // coordinator re-apply selection without reading through `controller.selectionState`.
        var cachedSelectedIDs: Set<String> = []
        var cachedPrimaryID: String?

        init(parent: IconCollectionViewRepresentable) {
            self.controller = parent.controller
            self.lastKnownScale = parent.controller.previewScale
            super.init()
        }

        private func rebuildFileIDIndex() {
            fileIDToIndex.removeAll(keepingCapacity: true)
            for (index, file) in files.enumerated() {
                fileIDToIndex[file.id] = index
            }
        }

        @discardableResult
        func applyUpdates(with newFiles: [FileItem]) -> Bool {
            let scaleChanged = abs(lastKnownScale - controller.previewScale) > 0.0001

            // Fast path: skip all work if nothing changed (e.g. selection-only update)
            if files == newFiles && !scaleChanged {
                return false
            }

            let oldFiles = files
            files = newFiles
            rebuildFileIDIndex()

            if scaleChanged {
                lastKnownScale = controller.previewScale
                collectionView?.reloadData()
                applySelectionFromCache()
                return true
            }

            guard let collectionView else { return false }

            let oldIDs = oldFiles.map { $0.id }
            let newIDs = newFiles.map { $0.id }

            if oldIDs == newIDs {
                // Same files, just metadata may have changed - lightweight update
                for indexPath in collectionView.indexPathsForVisibleItems() {
                    guard indexPath.item < newFiles.count,
                          let item = collectionView.item(at: indexPath) as? IconCollectionItem else { continue }
                    item.updateMetadata(with: newFiles[indexPath.item])
                }
                return false
            }

            let oldSet = Set(oldIDs)
            let newSet = Set(newIDs)
            let removedIDs = oldSet.subtracting(newSet)
            let insertedIDs = newSet.subtracting(oldSet)

            let removeIndexPaths = Set(oldIDs.enumerated().compactMap { index, id in
                removedIDs.contains(id) ? IndexPath(item: index, section: 0) : nil
            })
            let insertIndexPaths = Set(newIDs.enumerated().compactMap { index, id in
                insertedIDs.contains(id) ? IndexPath(item: index, section: 0) : nil
            })

            // Check if surviving items were reordered (batch update can't handle this)
            let oldSurvivors = oldIDs.filter { newSet.contains($0) }
            let newSurvivors = newIDs.filter { oldSet.contains($0) }
            let hasReorder = oldSurvivors != newSurvivors

            if hasReorder || (removeIndexPaths.isEmpty && insertIndexPaths.isEmpty) {
                collectionView.reloadData()
            } else {
                collectionView.performBatchUpdates({
                    if !removeIndexPaths.isEmpty {
                        collectionView.deleteItems(at: removeIndexPaths)
                    }
                    if !insertIndexPaths.isEmpty {
                        collectionView.insertItems(at: insertIndexPaths)
                    }
                }, completionHandler: nil)
            }

            applySelectionFromCache()
            return true
        }

        func applySelection() {
            if skipNextSelectionSync {
                skipNextSelectionSync = false
                return
            }
            applySelectionFromCache()
        }

        func handleCommandKey(_ event: NSEvent) -> Bool {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommand = modifiers.contains(.command)

            if isCommand, let character = event.charactersIgnoringModifiers?.lowercased() {
                switch character {
                case "c":
                    controller.copySelectedFilesToPasteboard()
                    return true
                case "x":
                    controller.cutSelectedFilesToPasteboard()
                    return true
                case "v":
                    controller.pasteFilesFromPasteboard()
                    return true
                case "a":
                    collectionView?.selectAll(nil)
                    return true
                default:
                    break
                }

                if event.keyCode == 51 { // Command + Delete
                    controller.deleteSelectedFiles()
                    return true
                }
            }

            // Arrow key navigation (no modifiers)
            if modifiers.subtracting(.numericPad).isEmpty {
                switch event.keyCode {
                case 123: // Left
                    moveSelection(by: -1)
                    return true
                case 124: // Right
                    moveSelection(by: 1)
                    return true
                case 126: // Up
                    moveSelection(byRow: -1)
                    return true
                case 125: // Down
                    moveSelection(byRow: 1)
                    return true
                default:
                    break
                }
            }

            return false
        }

        private func moveSelection(by offset: Int) {
            guard let collectionView, files.count > 0 else { return }
            let currentIndex: Int = {
                if let path = lastUserSelectionIndexPath {
                    return path.item
                }
                return collectionView.selectionIndexPaths.first?.item ?? 0
            }()
            let newIndex = max(0, min(files.count - 1, currentIndex + offset))
            let newPath = IndexPath(item: newIndex, section: 0)
            lastUserSelectionIndexPath = newPath
            collectionView.selectionIndexPaths = [newPath]
            collectionView.scrollToItems(at: [newPath], scrollPosition: .centeredVertically)
            scheduleSelectionSync()
        }

        private func moveSelection(byRow delta: Int) {
            guard let collectionView, files.count > 0 else { return }
            guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else {
                moveSelection(by: delta)
                return
            }
            let itemWidth = layout.itemSize.width + layout.minimumInteritemSpacing
            let viewportWidth = collectionView.bounds.width - layout.sectionInset.left - layout.sectionInset.right
            let columnCount = max(1, Int((viewportWidth + layout.minimumInteritemSpacing) / itemWidth))

            let currentIndex: Int = {
                if let path = lastUserSelectionIndexPath {
                    return path.item
                }
                return collectionView.selectionIndexPaths.first?.item ?? 0
            }()
            let newIndex = max(0, min(files.count - 1, currentIndex + delta * columnCount))
            let newPath = IndexPath(item: newIndex, section: 0)
            lastUserSelectionIndexPath = newPath
            collectionView.selectionIndexPaths = [newPath]
            collectionView.scrollToItems(at: [newPath], scrollPosition: .centeredVertically)
            scheduleSelectionSync()
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            files.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            guard let item = collectionView.makeItem(withIdentifier: IconCollectionItem.reuseIdentifier, for: indexPath) as? IconCollectionItem else {
                return NSCollectionViewItem()
            }
            guard indexPath.item < files.count else { return item }
            let file = files[indexPath.item]
            item.configure(with: file, metrics: currentMetrics)
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard suppressSelectionUpdates == false else { return }

            let newest = indexPaths.sorted(by: { $0.item < $1.item }).last
                ?? collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).last
            if let newest {
                lastUserSelectionIndexPath = newest
            }
            scheduleSelectionSync()
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            guard suppressSelectionUpdates == false else { return }
            let newest = collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).last
            lastUserSelectionIndexPath = newest
            scheduleSelectionSync()
        }

        // A single click that changes selection fires both didDeselect (for the old item)
        // and didSelect (for the new item). Without coalescing, each fires its own model
        // sync and a SwiftUI invalidation cycle. Defer to the next runloop turn so both
        // delegate calls collapse into one sync using the final NSCollectionView state.
        private var pendingSelectionSync = false

        private func scheduleSelectionSync() {
            guard !pendingSelectionSync else { return }
            pendingSelectionSync = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingSelectionSync = false
                self.syncControllerSelectionFromCollectionView(focused: self.lastUserSelectionIndexPath)
            }
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            currentMetrics.itemSize
        }

        func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
            guard indexPath.item < files.count else { return nil }
            return files[indexPath.item].url as NSURL
        }

        func collectionView(_ collectionView: NSCollectionView, menuForItemsAt indexPaths: Set<IndexPath>, point: NSPoint) -> NSMenu? {
            var effectiveIndexPaths = indexPaths
            if effectiveIndexPaths.isEmpty,
               let hovered = collectionView.indexPathForItem(at: point) {
                collectionView.selectionIndexPaths = [hovered]
                lastUserSelectionIndexPath = hovered
                syncControllerSelectionFromCollectionView(focused: hovered)
                effectiveIndexPaths = [hovered]
            }

            guard let indexPath = effectiveIndexPaths.first, indexPath.item < files.count else { return nil }
            let file = files[indexPath.item]
            let menu = NSMenu(title: NSLocalizedString("menu.file", comment: "File menu title"))
            let showInFinder = NSMenuItem(title: NSLocalizedString("contextMenu.showInFinder", comment: "Show in Finder"), action: #selector(openInFinder(_:)), keyEquivalent: "")
            showInFinder.target = self
            showInFinder.representedObject = file
            menu.addItem(showInFinder)

            if file.isDirectory == false {
                let openItem = NSMenuItem(title: NSLocalizedString("contextMenu.openFile", comment: "Open file"), action: #selector(openFile(_:)), keyEquivalent: "")
                openItem.target = self
                openItem.representedObject = file
                menu.addItem(openItem)
            }

            return menu
        }

        func handleDoubleClick(at point: NSPoint) {
            guard let collectionView,
                  let indexPath = collectionView.indexPathForItem(at: point),
                  indexPath.item < files.count else { return }

            lastUserSelectionIndexPath = indexPath
            collectionView.selectionIndexPaths = [indexPath]
            scheduleSelectionSync()
            NSWorkspace.shared.open(files[indexPath.item].url)
        }

        @objc private func openInFinder(_ sender: NSMenuItem) {
            guard let file = sender.representedObject as? FileItem else { return }
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        }

        @objc private func openFile(_ sender: NSMenuItem) {
            guard let file = sender.representedObject as? FileItem else { return }
            NSWorkspace.shared.open(file.url)
        }

        private func syncControllerSelectionFromCollectionView(focused indexPath: IndexPath?) {
            guard let collectionView else { return }

            let indexPaths = collectionView.selectionIndexPaths
            let ids = Set(indexPaths.compactMap { path -> String? in
                guard path.item < files.count else { return nil }
                return files[path.item].id
            })

            let primaryID: String? = {
                if let indexPath, indexPaths.contains(indexPath), indexPath.item < files.count {
                    return files[indexPath.item].id
                }
                if let lastPath = lastUserSelectionIndexPath,
                   indexPaths.contains(lastPath),
                   lastPath.item < files.count {
                    return files[lastPath.item].id
                }
                if let fallback = indexPaths.sorted(by: { $0.item < $1.item }).last,
                   fallback.item < files.count {
                    return files[fallback.item].id
                }
                return nil
            }()

            skipNextSelectionSync = true
            controller.updateSelection(ids: ids, primaryID: primaryID)
        }

        @discardableResult
        fileprivate func layoutMetrics(for collectionView: NSCollectionView) -> IconCollectionLayoutMetrics {
            guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else {
                let fallback = IconCollectionLayoutMetrics(
                    itemSize: NSSize(width: 140, height: 180),
                    thumbnailSize: NSSize(width: 120, height: 120)
                )
                currentMetrics = fallback
                return fallback
            }

            let inset = layout.sectionInset
            let viewportWidth = collectionView.enclosingScrollView?.contentView.bounds.width ?? collectionView.bounds.width
            let availableWidth = max(viewportWidth - inset.left - inset.right, 100)
            let spacing = layout.minimumInteritemSpacing
            let maxColumns = 5
            let minWidth: CGFloat = 60
            let maxWidth: CGFloat = 200

            var targetWidth = 150 * controller.previewScale
            targetWidth = min(max(targetWidth, minWidth), maxWidth)

            var columnCount = Int((availableWidth + spacing) / (targetWidth + spacing))
            columnCount = max(1, min(maxColumns, columnCount))

            let maxAllowedWidth = (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
            let width = max(min(targetWidth, maxAllowedWidth), minWidth)
            let thumbnailWidth = max(width - 12, 50)
            let thumbnailHeight = max(thumbnailWidth * 0.75, 60)
            let totalHeight = thumbnailHeight + 50

            let metrics = IconCollectionLayoutMetrics(
                itemSize: NSSize(width: width, height: totalHeight),
                thumbnailSize: NSSize(width: thumbnailWidth, height: thumbnailHeight)
            )

            currentMetrics = metrics
            if layout.itemSize != metrics.itemSize {
                layout.itemSize = metrics.itemSize
                layout.invalidateLayout()
                collectionView.layoutSubtreeIfNeeded()
            }

            return metrics
        }

        private func applySelectionFromCache() {
            guard let collectionView else { return }

            let desiredIndexPaths = Set(cachedSelectedIDs.compactMap(indexPath(forFileID:)))
            let shouldUpdate = collectionView.selectionIndexPaths != desiredIndexPaths

            let wasSuppressing = suppressSelectionUpdates
            if !wasSuppressing { suppressSelectionUpdates = true }
            if shouldUpdate {
                collectionView.selectionIndexPaths = desiredIndexPaths
            }
            if let primaryID = cachedPrimaryID,
               let path = indexPath(forFileID: primaryID) {
                lastUserSelectionIndexPath = path
            } else {
                lastUserSelectionIndexPath = desiredIndexPaths.sorted(by: { $0.item < $1.item }).last
            }
            if !wasSuppressing { suppressSelectionUpdates = false }
        }

        private func indexPath(forFileID id: String) -> IndexPath? {
            fileIDToIndex[id].map { IndexPath(item: $0, section: 0) }
        }
    }
}

private struct IconCollectionLayoutMetrics {
    let itemSize: NSSize
    let thumbnailSize: NSSize
}

    private final class IconCollectionItem: NSCollectionViewItem {
        static let reuseIdentifier = NSUserInterfaceItemIdentifier("IconCollectionItem")

        private let roundedBackground = NSView()
        private let thumbnailView = NSImageView()
        private let tagIndicatorView = NSView()
        private let nameLabel = NSTextField(labelWithString: "")
        private let detailLabel = NSTextField(labelWithString: "")
        private let contentStack = NSStackView()
        private var thumbnailWidthConstraint: NSLayoutConstraint?
        private var thumbnailHeightConstraint: NSLayoutConstraint?
        private var thumbnailTask: Task<Void, Never>?
        private var currentFileID: String?

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        roundedBackground.wantsLayer = true
        if let layer = roundedBackground.layer {
            layer.cornerRadius = 12
            layer.masksToBounds = true
            layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer.borderWidth = 0
            layer.borderColor = NSColor.clear.cgColor
            layer.actions = [
                "backgroundColor": NSNull(),
                "borderColor": NSNull(),
                "borderWidth": NSNull()
            ]
        }

        thumbnailView.imageAlignment = .alignCenter
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 10
        thumbnailView.layer?.masksToBounds = true

        tagIndicatorView.wantsLayer = true
        tagIndicatorView.layer?.cornerRadius = 5
        tagIndicatorView.layer?.masksToBounds = true
        tagIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        tagIndicatorView.isHidden = true
        thumbnailView.addSubview(tagIndicatorView)

        NSLayoutConstraint.activate([
            tagIndicatorView.widthAnchor.constraint(equalToConstant: 10),
            tagIndicatorView.heightAnchor.constraint(equalToConstant: 10),
            tagIndicatorView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: -4),
            tagIndicatorView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: -4)
        ])

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 2
        nameLabel.alignment = .center
        nameLabel.textColor = .labelColor

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.maximumNumberOfLines = 1
        detailLabel.alignment = .center
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(contentStack)
        contentStack.addArrangedSubview(thumbnailView)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(detailLabel)
        contentStack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 4),
            contentStack.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -4),
            contentStack.topAnchor.constraint(equalTo: roundedBackground.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor, constant: -4)
        ])

        thumbnailWidthConstraint = thumbnailView.widthAnchor.constraint(equalToConstant: 120)
        thumbnailHeightConstraint = thumbnailView.heightAnchor.constraint(equalToConstant: 90)
        thumbnailWidthConstraint?.isActive = true
        thumbnailHeightConstraint?.isActive = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        currentFileID = nil
        thumbnailView.image = nil
        tagIndicatorView.isHidden = true
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
            view.setAccessibilitySelected(isSelected)
        }
    }

    func configure(with file: FileItem, metrics: IconCollectionLayoutMetrics) {
        currentFileID = file.id

        view.toolTip = file.url.path
        nameLabel.stringValue = file.displayName
        detailLabel.stringValue = detailText(for: file)
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel("\(file.displayName), \(detailText(for: file))")

        if let color = file.primaryTagColor {
            tagIndicatorView.layer?.backgroundColor = color.cgColor
            tagIndicatorView.isHidden = false
        } else {
            tagIndicatorView.isHidden = true
        }

        let thumbSize = metrics.thumbnailSize
        thumbnailWidthConstraint?.constant = thumbSize.width
        thumbnailHeightConstraint?.constant = thumbSize.height

        thumbnailTask?.cancel()

        // Sync cache check first — eliminates the generic-icon flash that previously
        // appeared every time a cell was configured, even when the thumbnail was
        // already cached. The async path runs only on a true cache miss.
        if file.isDirectory == false, let cached = ThumbnailCache.shared.image(for: file.url) {
            thumbnailView.image = cached
            updateSelectionAppearance()
            return
        }

        thumbnailView.image = FileIconCache.shared.icon(for: file.url, size: thumbSize)

        guard file.isDirectory == false else {
            updateSelectionAppearance()
            return
        }

        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            if let loaded = await ThumbnailCache.shared.loadThumbnail(
                for: file.url,
                size: thumbSize,
                sourceModified: file.modificationDate
            ) {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    applyThumbnailOnMain(loaded, for: file)
                }
            }
        }

        updateSelectionAppearance()
    }

    /// Lightweight update: only refresh text labels without touching thumbnails or starting tasks
    func updateMetadata(with file: FileItem) {
        // Defensive: ensure cell hasn't been recycled to a different file
        guard file.id == currentFileID else { return }
        nameLabel.stringValue = file.displayName
        detailLabel.stringValue = detailText(for: file)
    }

    @MainActor
    private func applyThumbnailOnMain(_ image: NSImage, for file: FileItem) {
        guard file.id == currentFileID else { return }
        thumbnailView.image = image
    }

    private func detailText(for file: FileItem) -> String {
        if file.isDirectory {
            return NSLocalizedString("folder", comment: "Folder label")
        }
        if let size = file.fileSize {
            let sizeText = IconCollectionItem.sizeFormatter.string(fromByteCount: size)
            return "\(file.relativeDateDescription) · \(sizeText)"
        }
        return file.relativeDateDescription
    }

    private func updateSelectionAppearance() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let borderColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        let backgroundColor: NSColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.30) : NSColor.windowBackgroundColor

        if let layer = roundedBackground.layer {
            layer.borderColor = borderColor
            layer.borderWidth = isSelected ? 1.8 : 0
            layer.backgroundColor = backgroundColor.cgColor
        }

        CATransaction.commit()
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}
