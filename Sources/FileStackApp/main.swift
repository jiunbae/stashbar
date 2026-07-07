import AppKit
import FileStackCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var keyboardMonitor: Any?
    private let controller = FileStackController()
    private lazy var settingsWindowController = SettingsWindowController(controller: controller)
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: NSLocalizedString("menu.settings", comment: "Settings menu item"), action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Quit menu item"), action: #selector(terminateApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Stashbar")
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
        if let monitor = keyboardMonitor {
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        positionPopover(relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event }
            self.closePopover(sender: nil)
            return nil
        }
    }

    private func closePopover(sender: Any?) {
        controller.setInterfaceActive(false)
        popover.performClose(sender)
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
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

// Wire up the localization bundle so FileStackCore strings resolve correctly.
// Bundle.module triggers an assertion if the resource bundle cannot be found,
// so we locate it manually and fall back to the main bundle.
let possibleBundlePaths = [
    Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/FileStackApp_FileStackApp.bundle"),
    Bundle.main.bundleURL.appendingPathComponent("Resources/FileStackApp_FileStackApp.bundle"),
    Bundle.main.resourceURL?.appendingPathComponent("FileStackApp_FileStackApp.bundle"),
].compactMap { $0 }

if let bundleURL = possibleBundlePaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
   let resourceBundle = Bundle(url: bundleURL) {
    Localization.bundle = resourceBundle
} else {
    Localization.bundle = Bundle.main
}

let app = NSApplication.shared
let retainedDelegate: NSObject

if let screenshotConfiguration = ScreenshotCaptureConfiguration.fromEnvironment() {
    let delegate = ScreenshotAppDelegate(configuration: screenshotConfiguration)
    retainedDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.regular)
} else {
    let delegate = AppDelegate()
    retainedDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
}

app.run()
