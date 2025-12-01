import AppKit
import Combine
import QuartzCore
import SwiftUI

private protocol IconCollectionCommandHandling: AnyObject {
    func handleCommandKey(_ event: NSEvent) -> Bool
}

private final class FileCollectionView: NSCollectionView {
    weak var commandHandler: IconCollectionCommandHandling?

    override func keyDown(with event: NSEvent) {
        if commandHandler?.handleCommandKey(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

struct IconCollectionViewRepresentable: NSViewRepresentable {
    let controller: FileStackController

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

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

        let doubleClickRecognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickRecognizer.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClickRecognizer)

        context.coordinator.doubleClickRecognizer = doubleClickRecognizer

        collectionView.commandHandler = context.coordinator
        context.coordinator.collectionView = collectionView

        scrollView.documentView = collectionView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.setController(controller)

        guard let collectionView = context.coordinator.collectionView,
              let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else {
            return
        }

        _ = context.coordinator.layoutMetrics(for: collectionView)
        let needsLayout = context.coordinator.applyUpdates(with: controller.currentFiles)
        context.coordinator.updateSelection(from: controller)

        if needsLayout {
            layout.invalidateLayout()
        }
    }

    final class Coordinator: NSObject, IconCollectionCommandHandling, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
        var controller: FileStackController
        var collectionView: NSCollectionView?
        private var files: [FileItem] = []
        private var suppressSelectionUpdates = false
        private var lastUserSelectionIndexPath: IndexPath?
        private var lastKnownScale: Double
        private var lastKnownSortOption: SortOption
        private var lastKnownSortDirection: SortDirection
        fileprivate var doubleClickRecognizer: NSClickGestureRecognizer?
        private var currentMetrics = IconCollectionLayoutMetrics(
            itemSize: NSSize(width: 140, height: 180),
            thumbnailSize: NSSize(width: 120, height: 120)
        )
        private var scaleCancellable: AnyCancellable?
        private var sortCancellables: Set<AnyCancellable> = []
        private var skipNextSelectionSync = false

        init(parent: IconCollectionViewRepresentable) {
            self.controller = parent.controller
            self.lastKnownScale = parent.controller.previewScale
            self.lastKnownSortOption = parent.controller.sortOption
            self.lastKnownSortDirection = parent.controller.sortDirection
            super.init()
            bindPreviewScale()
            bindSortChanges()
        }

        func setController(_ controller: FileStackController) {
            guard self.controller !== controller else { return }
            self.controller = controller
            lastKnownScale = controller.previewScale
            lastKnownSortOption = controller.sortOption
            lastKnownSortDirection = controller.sortDirection
            bindPreviewScale()
            bindSortChanges()
        }

        private func bindPreviewScale() {
            scaleCancellable?.cancel()
            scaleCancellable = controller.$previewScale
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.handlePreviewScaleChange()
                }
        }

        private func bindSortChanges() {
            sortCancellables.removeAll()

            controller.$sortOption
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.handleSortChange()
                }
                .store(in: &sortCancellables)

            controller.$sortDirection
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.handleSortChange()
                }
                .store(in: &sortCancellables)
        }

        private func handleSortChange() {
            guard let collectionView else { return }
            let sortChanged = lastKnownSortOption != controller.sortOption ||
                            lastKnownSortDirection != controller.sortDirection

            if sortChanged {
                lastKnownSortOption = controller.sortOption
                lastKnownSortDirection = controller.sortDirection
                // Force immediate reload with new sorted data
                files = controller.currentFiles
                collectionView.reloadData()
                applySelectionFromController()
            }
        }

        private func handlePreviewScaleChange() {
            guard let collectionView else { return }
            lastKnownScale = controller.previewScale
            _ = layoutMetrics(for: collectionView)
            collectionView.reloadData()
            applySelectionFromController()
        }

        @discardableResult
        func applyUpdates(with newFiles: [FileItem]) -> Bool {
            let scaleChanged = abs(lastKnownScale - controller.previewScale) > 0.0001
            let dataChanged = files != newFiles
            files = newFiles
            if dataChanged || scaleChanged {
                collectionView?.reloadData()
                lastKnownScale = controller.previewScale
                applySelectionFromController()
                return true
            }
            return false
        }

        func updateSelection(from controller: FileStackController) {
            if skipNextSelectionSync {
                skipNextSelectionSync = false
                return
            }
            applySelectionFromController()
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

            if event.keyCode == 51 { // Delete
                controller.deleteSelectedFiles()
                return true
            }

            return false
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            files.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            guard let item = collectionView.makeItem(withIdentifier: IconCollectionItem.reuseIdentifier, for: indexPath) as? IconCollectionItem else {
                return NSCollectionViewItem()
            }
            let file = files[indexPath.item]
            let metrics = layoutMetrics(for: collectionView)
            item.configure(with: file, metrics: metrics)
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard suppressSelectionUpdates == false else { return }

            let newest = indexPaths.sorted(by: { $0.item < $1.item }).last
                ?? collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).last
            if let newest {
                lastUserSelectionIndexPath = newest
            }
            syncControllerSelectionFromCollectionView(focused: newest)
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            guard suppressSelectionUpdates == false else { return }
            let newest = collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).last
            lastUserSelectionIndexPath = newest
            syncControllerSelectionFromCollectionView(focused: newest)
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            layoutMetrics(for: collectionView).itemSize
        }

        func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
            files[indexPath.item].url as NSURL
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

            guard let indexPath = effectiveIndexPaths.first else { return nil }
            let file = files[indexPath.item]
            let menu = NSMenu(title: "파일")
            let showInFinder = NSMenuItem(title: "Finder에서 보기", action: #selector(openInFinder(_:)), keyEquivalent: "")
            showInFinder.target = self
            showInFinder.representedObject = file
            menu.addItem(showInFinder)

            if file.isDirectory == false {
                let openItem = NSMenuItem(title: "파일 열기", action: #selector(openFile(_:)), keyEquivalent: "")
                openItem.target = self
                openItem.representedObject = file
                menu.addItem(openItem)
            }

            return menu
        }

        @objc func handleDoubleClick(_ sender: Any?) {
            guard let gesture = sender as? NSClickGestureRecognizer,
                  gesture.state == .ended,
                  let collectionView else { return }

            let point = gesture.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: point),
                  indexPath.item < files.count else { return }

            lastUserSelectionIndexPath = indexPath
            collectionView.selectionIndexPaths = [indexPath]
            syncControllerSelectionFromCollectionView(focused: indexPath)
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
            let thumbnailWidth = max(width - 20, 50)
            let thumbnailHeight = max(thumbnailWidth * 0.75, 60)
            let totalHeight = thumbnailHeight + 64

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

        private func applySelectionFromController() {
            guard let collectionView else { return }

            let desiredIndexPaths = Set(controller.selectedFileIDs.compactMap(indexPath(forFileID:)))
            let shouldUpdate = collectionView.selectionIndexPaths != desiredIndexPaths

            let wasSuppressing = suppressSelectionUpdates
            if !wasSuppressing { suppressSelectionUpdates = true }
            if shouldUpdate {
                collectionView.selectionIndexPaths = desiredIndexPaths
            }
            if let primaryID = controller.primarySelectedFileID,
               let path = indexPath(forFileID: primaryID) {
                lastUserSelectionIndexPath = path
            } else {
                lastUserSelectionIndexPath = desiredIndexPaths.sorted(by: { $0.item < $1.item }).last
            }
            if !wasSuppressing { suppressSelectionUpdates = false }
        }

        private func indexPath(forFileID id: String) -> IndexPath? {
            guard let index = files.firstIndex(where: { $0.id == id }) else { return nil }
            return IndexPath(item: index, section: 0)
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
        contentStack.spacing = 8
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

            contentStack.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 8),
            contentStack.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -8),
            contentStack.topAnchor.constraint(equalTo: roundedBackground.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor, constant: -8)
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
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    func configure(with file: FileItem, metrics: IconCollectionLayoutMetrics) {
        currentFileID = file.id

        view.toolTip = file.url.path
        nameLabel.stringValue = file.displayName
        detailLabel.stringValue = detailText(for: file)

        let thumbSize = metrics.thumbnailSize
        thumbnailWidthConstraint?.constant = thumbSize.width
        thumbnailHeightConstraint?.constant = thumbSize.height

        thumbnailTask?.cancel()
        thumbnailView.image = FileIconCache.shared.icon(for: file.url, size: thumbSize)

        guard file.isDirectory == false else {
            updateSelectionAppearance()
            return
        }

        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            if let cached = ThumbnailCache.shared.image(for: file.url) {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    applyThumbnailOnMain(cached, for: file)
                }
                return
            }

            if let loaded = await ThumbnailCache.shared.loadThumbnail(for: file.url, size: thumbSize) {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    applyThumbnailOnMain(loaded, for: file)
                }
            }
        }

        updateSelectionAppearance()
    }

    @MainActor
    private func applyThumbnailOnMain(_ image: NSImage, for file: FileItem) {
        guard file.id == currentFileID else { return }
        thumbnailView.image = image
    }

    private func detailText(for file: FileItem) -> String {
        if file.isDirectory {
            return "폴더"
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
        let backgroundColor: NSColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.windowBackgroundColor

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
