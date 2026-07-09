import FileStackCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: FileStackController
    @StateObject private var tipJar = TipJar()

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

    private var maxItemsBinding: Binding<Int> {
        Binding(
            get: { controller.maxItemsPerFolder },
            set: { controller.setMaxItemsPerFolder($0) }
        )
    }

    private let maxItemsOptions = [10, 20, 40, 60, 80, 100, 200]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section(NSLocalizedString("settings.section.general", comment: "General settings section")) {
                    Toggle(NSLocalizedString("settings.launchAtLogin", comment: "Launch at login toggle"), isOn: launchAtLoginBinding)

                    Picker(NSLocalizedString("settings.maxItems", comment: "Max items per folder"), selection: maxItemsBinding) {
                        ForEach(maxItemsOptions, id: \.self) { count in
                            Text(String(format: NSLocalizedString("settings.maxItems.count", comment: "Item count"), count)).tag(count)
                        }
                    }
                }

                Section(NSLocalizedString("settings.section.view", comment: "View settings section")) {
                    Picker(NSLocalizedString("settings.defaultViewMode", comment: "Default view mode picker"), selection: viewModeBinding) {
                        ForEach(FileViewMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Slider(value: previewScaleBinding, in: 0.4...1.8, step: 0.1)
                        Text(String(format: NSLocalizedString("settings.previewSize", comment: "Preview size label"), previewScaleDescription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(NSLocalizedString("settings.section.folderManagement", comment: "Folder management section")) {
                    if controller.folders.isEmpty {
                        Text(NSLocalizedString("settings.noWatchedFolders", comment: "No watched folders"))
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
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button {
                                    controller.toggleFavorite(folder)
                                } label: {
                                    Image(systemName: folder.isFavorite ? "star.fill" : "star")
                                        .foregroundStyle(folder.isFavorite ? .yellow : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .help(folder.isFavorite ? Localization.string("button.unfavorite") : Localization.string("button.favorite"))

                                Button(NSLocalizedString("button.remove", comment: "Remove button")) {
                                    controller.removeFolder(folder)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        controller.presentFolderSelectionPanel()
                    } label: {
                        Label(NSLocalizedString("button.addFolder", comment: "Add folder button"), systemImage: "plus")
                    }
                }

                Section(NSLocalizedString("settings.section.support", comment: "Support development section")) {
                    Text(NSLocalizedString("settings.support.blurb", comment: "Support blurb"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if tipJar.products.isEmpty {
                        HStack(spacing: 8) {
                            if tipJar.isLoading {
                                ProgressView().controlSize(.small)
                            }
                            Text(NSLocalizedString(tipJar.isLoading ? "settings.support.loading" : "settings.support.unavailable", comment: "Tip loading state"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(tipJar.products, id: \.id) { product in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                    Text(product.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Button {
                                    Task { await tipJar.purchase(product) }
                                } label: {
                                    if tipJar.purchasingProductID == product.id {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text(product.displayPrice)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tipJar.purchasingProductID != nil)
                            }
                        }
                    }

                    if tipJar.thankedProductID != nil {
                        Label(NSLocalizedString("settings.support.thanks", comment: "Thank you message"), systemImage: "heart.fill")
                            .font(.callout)
                            .foregroundStyle(.pink)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(24)
            .task { await tipJar.loadProducts() }
        }
        .frame(minWidth: 420, minHeight: 320)
        .alert(Text(NSLocalizedString("alert.error.title", comment: "Alert title")), isPresented: alertBinding) {
            Button(NSLocalizedString("button.ok", comment: "OK button"), role: .cancel) {
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
