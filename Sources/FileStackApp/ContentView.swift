import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: FileStackController
    @State private var presentingFolderImporter = false

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
                List {
                    ForEach(controller.selectedFiles) { file in
                        FileRow(file: file)
                            .onTapGesture(count: 2) {
                                NSWorkspace.shared.open(file.url)
                            }
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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

private struct FileRow: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 12) {
            FileIconView(url: file.url)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        let time = file.relativeDateDescription
        if let size = file.fileSize {
            let sizeText = FileRow.byteFormatter.string(fromByteCount: size)
            return "\(time) · \(sizeText)"
        }
        return time
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct FileIconView: View {
    let url: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .cornerRadius(4)
    }
}
