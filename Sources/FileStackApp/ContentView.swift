import AppKit
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            fileListSection
            footerSection
        }
        .padding(16)
        .frame(width: 360, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("문제가 발생했습니다", isPresented: alertBinding) {
            Button("확인", role: .cancel) {
                controller.clearAlert()
            }
        } message: {
            Text(controller.alertMessage ?? "")
        }
        .overlay(
            KeyEventHandlingView(selectedFile: controller.selectedFile)
                .frame(width: 0, height: 0)
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                if controller.folders.isEmpty {
                    Text("감시할 폴더를 추가하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let selected = controller.selectedFolder {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                        Picker("폴더", selection: Binding(
                            get: { controller.selectedFolderID ?? selected.id },
                            set: { controller.selectedFolderID = $0 }
                        )) {
                            ForEach(controller.folders) { folder in
                                Text(folder.displayName)
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
                        Picker("정렬 기준", selection: sortOptionBinding) {
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
                    .help("정렬 기준: \(controller.sortOption.title)")

                    Button {
                        let newDirection: SortDirection = controller.sortDirection == .descending ? .ascending : .descending
                        controller.setSortDirection(newDirection)
                    } label: {
                        Image(systemName: controller.sortDirection.systemImageName)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .fixedSize()
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
                }
                .fixedSize()
            }

            if controller.folders.isEmpty {
                Text("상단 아이콘을 눌러 폴더를 등록하면 파일을 바로 모아볼 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let selected = controller.selectedFolder {
                Text(selected.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var fileListSection: some View {
        Group {
            if controller.currentFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("표시할 파일이 없습니다.")
                        .font(.subheadline)
                    Text("스크린샷을 찍거나 파일을 폴더에 추가하면 여기에서 바로 확인할 수 있습니다.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
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
    }

    private var iconGridView: some View {
        IconCollectionViewRepresentable(controller: controller)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(controller.currentFiles) { file in
                    FileListRow(
                        file: file,
                        isSelected: controller.isFileSelected(file),
                        iconSize: CGSize(width: 28, height: 28),
                        onSelect: { modifiers in
                            controller.handleSelection(of: file, modifiers: modifiers)
                        },
                        onOpen: {
                            NSWorkspace.shared.open(file.url)
                        }
                    )
                    .contextMenu {
                        Button("Finder에서 보기") {
                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                        }
                        Button("파일 열기") {
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

    private var hierarchyView: some View {
        if let folderURL = controller.selectedFolder?.url {
            let refreshToken = controller.currentFiles.map { $0.id }.joined(separator: ":")
            return AnyView(
                HierarchyBrowser(
                    rootURL: folderURL,
                    refreshToken: refreshToken,
                    selectedFileIDs: controller.selectedFileIDs,
                    onSelect: { file, modifiers in controller.handleSelection(of: file, modifiers: modifiers) },
                    onOpen: { NSWorkspace.shared.open($0.url) }
                )
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button {
                controller.presentFolderSelectionPanel()
            } label: {
                Label("폴더 추가", systemImage: "folder.badge.plus")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help("폴더 추가")

            if let folder = controller.selectedFolder {
                Button(role: .destructive) {
                    controller.removeFolder(folder)
                } label: {
                    Label("폴더 삭제", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(controller.folders.count <= 1)
                .help("폴더 삭제")
            }

            Button {
                controller.refreshSelectedFolder()
            } label: {
                Label("새로 고침", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help("새로 고침")

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
                .help("아이콘 크기 조절")
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
            return "폴더"
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
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
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
                    Text("폴더 구조를 불러오는 중…")
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
                                Button("Finder에서 보기") {
                                    NSWorkspace.shared.activateFileViewerSelecting([entry.file.url])
                                }
                                if entry.file.isDirectory == false {
                                    Button("파일 열기") {
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
                        Text("하위 항목이 없습니다.")
                            .font(.subheadline)
                        Text("새로운 폴더나 파일을 추가하면 여기에서 탐색할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("폴더 구조를 불러오는 중…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: refreshToken) {
            await loadTree()
        }
        .onChange(of: refreshToken) { _ in
            rootEntry = nil
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
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
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
            return "폴더"
        }
        if let size = entry.file.fileSize {
            let sizeText = fileSizeFormatter.string(fromByteCount: size)
            return "\(entry.file.relativeDateDescription) · \(sizeText)"
        }
        return entry.file.relativeDateDescription
    }

    private var iconSize: CGSize { CGSize(width: 20, height: 20) }
}

private let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
}()
