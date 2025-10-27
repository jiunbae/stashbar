import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: FileStackController

    private var viewModeBinding: Binding<FileViewMode> {
        Binding(
            get: { controller.viewMode },
            set: { controller.setViewMode($0) }
        )
    }

    private var previewScaleBinding: Binding<Double> {
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { controller.launchesAtLogin },
            set: { controller.setLaunchAtLogin($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("일반") {
                    Toggle("로그인 시 자동 실행", isOn: launchAtLoginBinding)
                }

                Section("보기") {
                    Picker("기본 보기 방식", selection: viewModeBinding) {
                        ForEach(FileViewMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Slider(value: previewScaleBinding, in: 0.4...1.8, step: 0.1)
                        Text("미리보기 크기: \(previewScaleDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("폴더 관리") {
                    if controller.folders.isEmpty {
                        Text("감시 중인 폴더가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.folders) { folder in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.displayName)
                                        .font(.body)
                                    Text(folder.url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("제거") {
                                    controller.removeFolder(folder)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        controller.presentFolderSelectionPanel()
                    } label: {
                        Label("폴더 추가", systemImage: "plus")
                    }
                }
            }
            .formStyle(.grouped)
            .padding(24)
        }
        .frame(minWidth: 420, minHeight: 320)
        .alert("문제가 발생했습니다", isPresented: alertBinding) {
            Button("확인", role: .cancel) {
                controller.clearAlert()
            }
        } message: {
            Text(controller.alertMessage ?? "")
        }
    }

    private var previewScaleDescription: String {
        let percent = Int(controller.previewScale * 100)
        return "\(percent)%"
    }
}
