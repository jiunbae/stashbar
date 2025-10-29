import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private let controller = FileStackController()
    private lazy var settingsWindowController = SettingsWindowController(controller: controller)
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "설정...", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(terminateApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "File Stack")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller))

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover(sender: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        let isRightClick = event.type == .rightMouseUp
            || event.type == .otherMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            closePopover(sender: nil)
            showStatusItemMenu(with: event)
        } else {
            togglePopover(sender)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }

    private func showPopover(sender: Any?) {
        guard let button = statusItem.button else { return }
        controller.setInterfaceActive(true)
        popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        positionPopover(relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover(sender: Any?) {
        controller.setInterfaceActive(false)
        popover.performClose(sender)
    }

    private func showStatusItemMenu(with event: NSEvent) {
        guard let button = statusItem.button else { return }
        NSMenu.popUpContextMenu(statusMenu, with: event, for: button)
    }

    private func positionPopover(relativeTo button: NSStatusBarButton) {
        guard
            let popoverWindow = popover.contentViewController?.view.window,
            let buttonWindow = button.window,
            let screen = buttonWindow.screen
        else {
            return
        }

        let buttonBoundsInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonBoundsInWindow)
        var frame = popoverWindow.frame
        let visibleFrame = screen.visibleFrame

        frame.origin.x = buttonRectOnScreen.midX - frame.width / 2
        frame.origin.y = buttonRectOnScreen.minY - frame.height - 8

        if frame.origin.x < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
        }
        if frame.origin.y < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }

        popoverWindow.setFrame(frame, display: true)
    }

    @objc private func openSettings(_ sender: Any?) {
        closePopover(sender: sender)
        settingsWindowController.show()
    }

    @objc private func terminateApp(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
