import AppKit
import QuickLook
import QuickLookUI
import SwiftUI

struct KeyEventHandlingView: NSViewRepresentable {
    var selectedFile: FileItem?

    func makeNSView(context: Context) -> KeyEventHandlingNSView {
        let view = KeyEventHandlingNSView()
        view.updateSelectedFile(selectedFile)
        return view
    }

    func updateNSView(_ nsView: KeyEventHandlingNSView, context: Context) {
        nsView.updateSelectedFile(selectedFile)
    }
}

final class KeyEventHandlingNSView: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private(set) var selectedFile: FileItem?
    private var previewItems: [FileItem] = []
    private var keyMonitor: Any?

    func updateSelectedFile(_ newFile: FileItem?) {
        let oldFile = selectedFile
        selectedFile = newFile

        // Refresh preview panel if:
        // 1. The file ID changed (different file selected)
        // 2. The file is the same path but might have different content (same ID but panel is visible)
        let idChanged = oldFile?.id != newFile?.id
        let panel = QLPreviewPanel.sharedPreviewPanelExists() ? QLPreviewPanel.shared() : nil
        let panelNeedsRefresh = panel?.isVisible == true

        if idChanged || panelNeedsRefresh {
            refreshPreviewPanel()
        }
    }

    override var acceptsFirstResponder: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startMonitoringKeys()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopMonitoringKeys()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit {
        stopMonitoringKeys()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: // Space
            toggleQuickLook()
        default:
            super.keyDown(with: event)
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
        previewItems[index].url as NSURL
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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 49 { // Space
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
