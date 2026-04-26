import AppKit
import QuickLook
import QuickLookUI
import SwiftUI

struct KeyEventHandlingView: NSViewRepresentable {
    var selectedFile: FileItem?
    var refreshToken: Int

    func makeNSView(context: Context) -> KeyEventHandlingNSView {
        let view = KeyEventHandlingNSView()
        view.updateState(selectedFile: selectedFile, token: refreshToken)
        return view
    }

    func updateNSView(_ nsView: KeyEventHandlingNSView, context: Context) {
        nsView.updateState(selectedFile: selectedFile, token: refreshToken)
    }
}

final class KeyEventHandlingNSView: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private(set) var selectedFile: FileItem?
    private var lastToken: Int?
    private var previewItems: [FileItem] = []
    private var keyMonitor: Any?

    func updateState(selectedFile newFile: FileItem?, token: Int) {
        let oldFile = selectedFile
        let tokenChanged = lastToken != token

        self.selectedFile = newFile
        self.lastToken = token

        let idChanged = oldFile?.id != newFile?.id
        let panelVisible = QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true

        if idChanged || (tokenChanged && panelVisible) {
            refreshPreviewPanel()
        }
    }

    override var acceptsFirstResponder: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startMonitoringKeys()
    }

    deinit {
        if Thread.isMainThread {
            stopMonitoringKeys()
        } else {
            let monitor = keyMonitor
            DispatchQueue.main.async {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0, index < previewItems.count else { return nil }
        return previewItems[index].url as NSURL
    }

    private func toggleQuickLook() {
        guard let file = selectedFile else {
            NSSound.beep()
            return
        }

        previewItems = [file]

        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            panel.orderOut(self)
            return
        }

        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(self)
    }

    private func refreshPreviewPanel() {
        guard QLPreviewPanel.sharedPreviewPanelExists(),
              let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            if let file = selectedFile {
                previewItems = [file]
                panel.dataSource = self
                panel.delegate = self
                panel.reloadData()
                panel.currentPreviewItemIndex = 0
                panel.refreshCurrentPreviewItem()
            } else {
                panel.orderOut(self)
            }
        }
    }

    private func startMonitoringKeys() {
        stopMonitoringKeys()
        guard window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 49 { // Space
                if let responder = event.window?.firstResponder,
                   responder is NSText || responder is NSTextField {
                    return event
                }
                self.toggleQuickLook()
                return nil
            }
            return event
        }
    }

    private func stopMonitoringKeys() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func previewPanelWillClose(_ panel: QLPreviewPanel!) {}
}
