import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: FileStackController
    @State private var presentingFolderImporter = false
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
        .fileImporter(
            isPresented: $presentingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    controller.addFolder(url: url)
                }
            case .failure(let error):
                controller.alertMessage = error.localizedDescription
            }
        }
        .overlay(
            KeyEventHandlingView(selectedFile: controller.selectedFile)
                .frame(width: 0, height: 0)
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if controller.folders.isEmpty {
                    Text("감시할 폴더를 추가하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let selected = controller.selectedFolder {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
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
                    .frame(maxWidth: 220)
                }

                Spacer()

                Picker("", selection: viewModeBinding) {
                    ForEach(FileViewMode.allCases) { mode in
                        Image(systemName: mode.systemImageName)
                            .tag(mode)
                            .help(mode.title)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
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
            if controller.selectedFiles.isEmpty {
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
        let metrics = iconGridMetrics(for: controller.previewScale)
        return ScrollView {
            LazyVGrid(columns: metrics.columns, spacing: 12) {
                ForEach(controller.selectedFiles) { file in
                    FilePreviewTile(
                        file: file,
                        isSelected: controller.selectedFile?.id == file.id,
                        thumbnailSize: metrics.tileSize,
                        onSelect: {
                            controller.selectFile(file)
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

    private func iconGridMetrics(for scale: Double) -> IconGridMetrics {
        let contentWidth: CGFloat = 360 - 32 // 팝오버 폭 360, 좌우 패딩 16씩
        let spacing: CGFloat = 10
        let minWidth: CGFloat = 50
        let maxWidth: CGFloat = 200
        let maxColumns = 5

        var targetWidth = 150 * scale
        targetWidth = min(max(targetWidth, minWidth), maxWidth)

        var columnCount = Int((contentWidth + spacing) / (targetWidth + spacing))
        columnCount = max(1, min(maxColumns, columnCount))

        let width = (contentWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        let height = max(width * 0.75, 60)

        let columns = Array(repeating: GridItem(.flexible(minimum: width, maximum: width), spacing: spacing), count: columnCount)
        return IconGridMetrics(columns: columns, tileSize: CGSize(width: width, height: height))
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(controller.selectedFiles) { file in
                    FileListRow(
                        file: file,
                        isSelected: controller.selectedFile?.id == file.id,
                        iconSize: CGSize(width: 28, height: 28),
                        onSelect: {
                            controller.selectFile(file)
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
            let refreshToken = controller.selectedFiles.map { $0.id }.joined(separator: ":")
            return AnyView(
                HierarchyBrowser(
                    rootURL: folderURL,
                    refreshToken: refreshToken,
                    selectedFileID: controller.selectedFile?.id,
                    onSelect: { controller.selectFile($0) },
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
                presentingFolderImporter = true
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

private struct IconGridMetrics {
    let columns: [GridItem]
    let tileSize: CGSize
}

private struct FilePreviewTile: View {
    let file: FileItem
    let isSelected: Bool
    let thumbnailSize: CGSize
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FileThumbnailView(file: file, size: thumbnailSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.08),
            radius: isSelected ? 8 : 3,
            y: isSelected ? 4 : 2
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onSelect()
            onOpen()
        }
    }

    private var detailText: String {
        let time = file.relativeDateDescription
        if let size = file.fileSize {
            let sizeText = fileSizeFormatter.string(fromByteCount: size)
            return "\(time) · \(sizeText)"
        }
        return time
    }

    private var tileBackground: some ShapeStyle {
        Color(NSColor.controlBackgroundColor)
    }
}

private struct FileThumbnailView: View {
    let file: FileItem
    let size: CGSize
    @StateObject private var loader: ThumbnailLoader

    init(file: FileItem, size: CGSize) {
        self.file = file
        self.size = size
        _loader = StateObject(wrappedValue: ThumbnailLoader(file: file))
    }

    var body: some View {
        ZStack {
            placeholderBackground

            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: loaderKey) {
            await loader.ensureLoaded(targetSize: size)
        }
    }

    private var placeholderBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlAccentColor).opacity(0.08))
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(placeholderLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: size.width, height: size.height)
    }

    private var placeholderLabel: String {
        if file.isDirectory {
            return "폴더"
        }

        if let uti = file.typeIdentifier {
            return uti
        }
        return file.url.pathExtension.uppercased().isEmpty ? "파일" : file.url.pathExtension.uppercased()
    }

    private var loaderKey: String {
        file.id + "|" + String(Int(size.width)) + "x" + String(Int(size.height))
    }
}

private struct FileListRow: View {
    let file: FileItem
    let isSelected: Bool
    let iconSize: CGSize
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
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
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onSelect()
            onOpen()
        }
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
    let selectedFileID: String?
    let onSelect: (FileItem) -> Void
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
                                isSelected: selectedFileID == entry.file.id,
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
    let onSelect: (FileItem) -> Void
    let onOpen: (FileItem) -> Void

    var body: some View {
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
        .onTapGesture {
            onSelect(entry.file)
        }
        .onTapGesture(count: 2) {
            onSelect(entry.file)
            onOpen(entry.file)
        }
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
