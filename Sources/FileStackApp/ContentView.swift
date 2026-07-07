import AppKit
import FileStackCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: FileStackController
    private var viewModeBinding: Binding<FileViewMode> {
        Binding(
            get: { controller.viewMode },
            set: { controller.setViewMode($0) }
        )
    }

    private var iconScaleBinding: Binding<Double> {
        Binding(
            get: { controller.previewScale },
            set: { controller.setPreviewScale($0) }
        )
    }

    private var sortOptionBinding: Binding<SortOption> {
        Binding(
            get: { controller.sortOption },
            set: { controller.setSortOption($0) }
        )
    }

    private var sortDirectionBinding: Binding<SortDirection> {
        Binding(
            get: { controller.sortDirection },
            set: { controller.setSortDirection($0) }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { controller.alertMessage != nil },
            set: { newValue in
                if newValue == false {
                    controller.clearAlert()
                }
            }
        )
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { controller.searchText },
            set: { controller.setSearchText($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            fileListSection
            footerSection
        }
        .padding(16)
        .frame(width: 360, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .alert(Text(NSLocalizedString("alert.error.title", comment: "Alert title")), isPresented: alertBinding) {
            Button(NSLocalizedString("button.ok", comment: "OK button"), role: .cancel) {
                controller.clearAlert()
            }
        } message: {
            Text(controller.alertMessage ?? "")
        }
        .overlay(
            QuickLookOverlay(controller: controller, selection: controller.selectionState)
                .frame(width: 0, height: 0)
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                if controller.folders.isEmpty {
                    Text(NSLocalizedString("emptyState.addFolders", comment: "Empty state message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let selected = controller.selectedFolder {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                        Picker(NSLocalizedString("picker.folder", comment: "Folder picker label"), selection: Binding(
                            get: { controller.selectedFolderID ?? selected.id },
                            set: { controller.selectedFolderID = $0 }
                        )) {
                            ForEach(controller.folders) { folder in
                                HStack(spacing: 4) {
                                    if folder.isFavorite {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .imageScale(.small)
                                    }
                                    Text(folder.displayName)
                                }
                                .tag(folder.id as UUID?)
                            }
                        }
                        .labelsHidden()
                        .font(.system(size: 13))
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 0) {
                    Menu {
                        Picker(NSLocalizedString("sort.by", comment: "Sort by menu label"), selection: sortOptionBinding) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        Image(systemName: controller.sortOption.systemImageName)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(NSLocalizedString("accessibility.sortButton", comment: ""))
                    .help(String(format: NSLocalizedString("sort.by.tooltip", comment: "Sort by tooltip"), controller.sortOption.title))

                    Button {
                        let newDirection: SortDirection = controller.sortDirection == .descending ? .ascending : .descending
                        controller.setSortDirection(newDirection)
                    } label: {
                        Image(systemName: controller.sortDirection.systemImageName)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .accessibilityLabel(NSLocalizedString("accessibility.sortDirectionButton", comment: ""))
                    .help(controller.sortDirection.title)

                    Picker("", selection: viewModeBinding) {
                        ForEach(FileViewMode.allCases) { mode in
                            Image(systemName: mode.systemImageName)
                                .tag(mode)
                                .help(mode.title)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(NSLocalizedString("accessibility.viewModePicker", comment: ""))
                }
                .fixedSize()
            }

            if controller.folders.isEmpty {
                Text(NSLocalizedString("emptyState.addFolderHint", comment: "Add folder hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let selected = controller.selectedFolder {
                Text(selected.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                SearchField(text: searchTextBinding)
                    .frame(height: 22)
                    .accessibilityLabel(NSLocalizedString("accessibility.searchField", comment: "Search field label"))
            }
        }
    }

    private var fileListSection: some View {
        Group {
            if controller.currentFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: controller.searchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(controller.searchText.isEmpty
                         ? NSLocalizedString("emptyState.noFiles", comment: "No files empty state")
                         : NSLocalizedString("emptyState.noSearchResults", comment: "No search results"))
                        .font(.subheadline)
                    Text(controller.searchText.isEmpty
                         ? NSLocalizedString("emptyState.noFilesHint", comment: "No files hint")
                         : NSLocalizedString("emptyState.noSearchResultsHint", comment: "No search results hint"))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    if controller.folders.isEmpty {
                        Button {
                            controller.presentFolderSelectionPanel()
                        } label: {
                            Label(NSLocalizedString("button.addFolder", comment: "Add folder button"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch controller.viewMode {
                case .icon:
                    iconGridView
                case .list:
                    listView
                case .hierarchy:
                    hierarchyView
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    DispatchQueue.main.async {
                        self.controller.addFolder(url: url)
                    }
                }
            }
            return true
        }
    }

    private var iconGridView: some View {
        IconGridContainer(controller: controller, selection: controller.selectionState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        FileListContainer(controller: controller, selection: controller.selectionState)
    }

    @ViewBuilder
    private var hierarchyView: some View {
        if let folderURL = controller.selectedFolder?.url {
            HierarchyContainer(
                controller: controller,
                selection: controller.selectionState,
                rootURL: folderURL
            )
        }
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button {
                controller.presentFolderSelectionPanel()
            } label: {
                Label(NSLocalizedString("button.addFolder", comment: "Add folder button"), systemImage: "folder.badge.plus")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .accessibilityLabel(NSLocalizedString("accessibility.addFolderButton", comment: ""))
            .help(NSLocalizedString("button.addFolder", comment: "Add folder button"))

            if let folder = controller.selectedFolder {
                Button(role: .destructive) {
                    controller.removeFolder(folder)
                } label: {
                    Label(NSLocalizedString("button.removeFolder", comment: "Remove folder button"), systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(controller.folders.count <= 1)
                .accessibilityLabel(NSLocalizedString("accessibility.removeFolderButton", comment: ""))
                .help(NSLocalizedString("button.removeFolder", comment: "Remove folder button"))
            }

            Button {
                controller.refreshSelectedFolder()
            } label: {
                Label(NSLocalizedString("button.refresh", comment: "Refresh button"), systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .accessibilityLabel(NSLocalizedString("accessibility.refreshButton", comment: ""))
            .help(NSLocalizedString("button.refresh", comment: "Refresh button"))

            iconScaleControl

            Spacer()
        }
        .font(.caption)
    }
}

private extension ContentView {
    var iconScaleControl: some View {
        let controlWidth: CGFloat = 200
        return HStack(spacing: 6) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(.secondary)
            Slider(value: iconScaleBinding, in: 0.4...1.8)
                .frame(maxWidth: 150)
                .help(NSLocalizedString("slider.iconSize", comment: "Icon size slider tooltip"))
        }
        .frame(width: controlWidth)
        .opacity(controller.viewMode == .icon ? 1 : 0)
        .allowsHitTesting(controller.viewMode == .icon)
    }
}

private struct FileListRow: View {
    let file: FileItem
    let isSelected: Bool
    let iconSize: CGSize
    let onSelect: (NSEvent.ModifierFlags) -> Void
    let onOpen: () -> Void

    var body: some View {
        Button {
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            onSelect(modifiers)
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: FileIconCache.shared.icon(for: file.url, size: iconSize))
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize.width, height: iconSize.height)
                    .cornerRadius(4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let color = file.primaryTagColor {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
                onSelect(modifiers)
                onOpen()
            }
        )
    }

    private var detailText: String {
        if file.isDirectory {
            return NSLocalizedString("folder", comment: "Folder label")
        }

        let time = file.relativeDateDescription
        if let size = file.fileSize {
            let sizeText = fileSizeFormatter.string(fromByteCount: size)
            return "\(time) · \(sizeText)"
        }
        return time
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.accentColor.opacity(0.30) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
    }

}

// MARK: - Selection-aware containers
//
// These wrapper views observe `SelectionState` directly so that selection changes
// don't invalidate the entire `ContentView` body. Header/footer/folder picker
// remain bound only to `FileStackController`'s other published properties.

private struct IconGridContainer: View {
    @ObservedObject var controller: FileStackController
    @ObservedObject var selection: SelectionState

    var body: some View {
        IconCollectionViewRepresentable(
            controller: controller,
            selectedFileIDs: selection.selectedFileIDs,
            primarySelectedFileID: selection.primarySelectedFileID,
            previewScale: controller.previewScale,
            fileListGeneration: controller.fileListGeneration
        )
    }
}

private struct FileListContainer: View {
    @ObservedObject var controller: FileStackController
    @ObservedObject var selection: SelectionState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(controller.currentFiles) { file in
                    FileListRow(
                        file: file,
                        isSelected: selection.selectedFileIDs.contains(file.id),
                        iconSize: CGSize(width: 28, height: 28),
                        onSelect: { modifiers in
                            controller.handleSelection(of: file, modifiers: modifiers)
                        },
                        onOpen: {
                            NSWorkspace.shared.open(file.url)
                        }
                    )
                    .contextMenu {
                        Button(NSLocalizedString("contextMenu.showInFinder", comment: "Show in Finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                        }
                        Button(NSLocalizedString("contextMenu.openFile", comment: "Open file")) {
                            NSWorkspace.shared.open(file.url)
                        }
                    }
                    .onDrag {
                        NSItemProvider(object: file.url as NSURL)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HierarchyContainer: View {
    @ObservedObject var controller: FileStackController
    @ObservedObject var selection: SelectionState
    let rootURL: URL

    var body: some View {
        HierarchyBrowser(
            rootURL: rootURL,
            refreshToken: "\(controller.fileListGeneration)",
            selectedFileIDs: selection.selectedFileIDs,
            onSelect: { file, modifiers in controller.handleSelection(of: file, modifiers: modifiers) },
            onOpen: { NSWorkspace.shared.open($0.url) }
        )
    }
}

private struct QuickLookOverlay: View {
    @ObservedObject var controller: FileStackController
    @ObservedObject var selection: SelectionState

    var body: some View {
        let primaryID = selection.primarySelectedFileID
        let selectedFile = primaryID.flatMap { id in
            controller.currentFiles.first(where: { $0.id == id })
        }
        KeyEventHandlingView(
            selectedFile: selectedFile,
            refreshToken: controller.fileListGeneration
        )
    }
}

private struct HierarchyBrowser: View {
    let rootURL: URL
    let refreshToken: String
    let selectedFileIDs: Set<String>
    let onSelect: (FileItem, NSEvent.ModifierFlags) -> Void
    let onOpen: (FileItem) -> Void

    @State private var rootEntry: FileSystemEntry?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(NSLocalizedString("loading.folderStructure", comment: "Loading folder structure"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let rootEntry {
                if let children = rootEntry.children, children.isEmpty == false {
                    List {
                        OutlineGroup(children, children: \.children) { entry in
                            FileHierarchyRow(
                                entry: entry,
                                isSelected: selectedFileIDs.contains(entry.file.id),
                                onSelect: onSelect,
                                onOpen: onOpen
                            )
                            .contextMenu {
                                Button(NSLocalizedString("contextMenu.showInFinder", comment: "Show in Finder")) {
                                    NSWorkspace.shared.activateFileViewerSelecting([entry.file.url])
                                }
                                if entry.file.isDirectory == false {
                                    Button(NSLocalizedString("contextMenu.openFile", comment: "Open file")) {
                                        NSWorkspace.shared.open(entry.file.url)
                                    }
                                }
                            }
                            .onDrag {
                                NSItemProvider(object: entry.file.url as NSURL)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("emptyState.noSubItems", comment: "No sub-items"))
                            .font(.subheadline)
                        Text(NSLocalizedString("emptyState.noSubItemsHint", comment: "No sub-items hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(NSLocalizedString("loading.folderStructure", comment: "Loading folder structure"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: refreshToken) {
            await loadTree()
        }
    }

    private func loadTree() async {
        isLoading = true
        let entry = await Task.detached(priority: .userInitiated) {
            FileTreeBuilder.buildTree(at: rootURL, depthLimit: 4, childLimit: 60)
        }.value
        await MainActor.run {
            self.rootEntry = entry
            self.isLoading = false
        }
    }
}

private struct FileHierarchyRow: View {
    let entry: FileSystemEntry
    let isSelected: Bool
    let onSelect: (FileItem, NSEvent.ModifierFlags) -> Void
    let onOpen: (FileItem) -> Void

    var body: some View {
        Button {
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            onSelect(entry.file, modifiers)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: FileIconCache.shared.icon(for: entry.file.url, size: iconSize))
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize.width, height: iconSize.height)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.file.displayName)
                        .lineLimit(1)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if let color = entry.file.primaryTagColor {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.30) : .clear)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
                onSelect(entry.file, modifiers)
                onOpen(entry.file)
            }
        )
    }

    private var subtitleText: String? {
        if entry.file.isDirectory {
            return NSLocalizedString("folder", comment: "Folder label")
        }
        if let size = entry.file.fileSize {
            let sizeText = fileSizeFormatter.string(fromByteCount: size)
            return "\(entry.file.relativeDateDescription) · \(sizeText)"
        }
        return entry.file.relativeDateDescription
    }

    private var iconSize: CGSize { CGSize(width: 20, height: 20) }
}

private struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.placeholderString = NSLocalizedString("search.placeholder", comment: "")
        field.font = .systemFont(ofSize: 12)
        field.bezelStyle = .roundedBezel
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                text = field.stringValue
            }
        }
    }
}

private let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
}()
