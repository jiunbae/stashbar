import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let hostingController: NSHostingController<SettingsView>

    init(controller: FileStackController) {
        let settingsView = SettingsView(controller: controller)
        hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = NSLocalizedString("window.settings", comment: "Settings window title")
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
