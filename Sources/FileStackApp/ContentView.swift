import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: FileStackController
    @State private var presentingFolderImporter = false
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(minimum: 140, maximum: 200), spacing: 12),
        GridItem(.flexible(minimum: 140, maximum: 200), spacing: 12)
    ]

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
        VStack(alignment: .leading, spacing: 6) {
            Text("File Stack")
                .font(.headline)
            if controller.folders.isEmpty {
                Text("상단의 버튼을 눌러 감시할 폴더를 등록하세요. 기본으로 스크린샷 폴더를 탐색합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let selected = controller.selectedFolder {
                VStack(alignment: .leading, spacing: 2) {
                    Picker("폴더", selection: Binding(
                        get: { controller.selectedFolderID ?? selected.id },
                        set: { controller.selectedFolderID = $0 }
                    )) {
                        ForEach(controller.folders) { folder in
                            Text(folder.displayName)
                                .tag(folder.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(selected.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
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
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(controller.selectedFiles) { file in
                            FilePreviewTile(
                                file: file,
                                isSelected: controller.selectedFile?.id == file.id,
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
        }
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button {
                presentingFolderImporter = true
            } label: {
                Label("폴더 추가", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            if let folder = controller.selectedFolder {
                Button(role: .destructive) {
                    controller.removeFolder(folder)
                } label: {
                    Label("폴더 삭제", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(controller.folders.count <= 1)
            }

            Spacer()

            Button {
                controller.refreshSelectedFolder()
            } label: {
                Label("새로 고침", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .font(.caption)
    }
}

private struct FilePreviewTile: View {
    let file: FileItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FileThumbnailView(file: file)
                .frame(height: 140)

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
            let sizeText = FilePreviewTile.byteFormatter.string(fromByteCount: size)
            return "\(time) · \(sizeText)"
        }
        return time
    }

    private var tileBackground: some ShapeStyle {
        Color(NSColor.controlBackgroundColor)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct FileThumbnailView: View {
    let file: FileItem
    @State private var thumbnail: NSImage?

    private let targetSize = CGSize(width: 320, height: 240)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                placeholderBackground

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(placeholderLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .task(id: file.id) {
            await loadThumbnailIfNeeded()
        }
    }

    private var placeholderBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlAccentColor).opacity(0.08))
    }

    private var placeholderLabel: String {
        if let uti = file.typeIdentifier {
            return uti
        }
        return file.url.pathExtension.uppercased().isEmpty ? "파일" : file.url.pathExtension.uppercased()
    }

    private func loadThumbnailIfNeeded() async {
        if thumbnail != nil {
            return
        }

        if let cached = ThumbnailCache.shared.image(for: file.url) {
            await MainActor.run {
                thumbnail = cached
            }
            return
        }

        let image = await ThumbnailCache.shared.loadThumbnail(for: file.url, size: targetSize)
        await MainActor.run {
            thumbnail = image
        }
    }
}
