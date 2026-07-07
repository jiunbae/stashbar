import AppKit
import CoreGraphics
import FileStackCore
import SwiftUI

enum ScreenshotScene: String, CaseIterable {
    case iconGrid = "icon-grid"
    case folderSwitching = "folder-switching"
    case listView = "list-view"
    case hierarchyView = "hierarchy-view"

    struct Descriptor {
        let folderNames: [String]
        let selectedFolderName: String
        let selectedDisplayNames: [String]
        let viewMode: FileViewMode
        let previewScale: Double
        let sortOption: SortOption
        let sortDirection: SortDirection
        let outputFilename: String
    }

    var descriptor: Descriptor {
        switch self {
        case .iconGrid:
            return Descriptor(
                folderNames: ["Screenshots", "Downloads", "Workspace"],
                selectedFolderName: "Screenshots",
                selectedDisplayNames: ["Cover.png", "Card.jpg"],
                viewMode: .icon,
                previewScale: 1.55,
                sortOption: .dateModified,
                sortDirection: .descending,
                outputFilename: "01-live-icon-grid.png"
            )
        case .folderSwitching:
            return Descriptor(
                folderNames: ["Screenshots", "Downloads", "Workspace"],
                selectedFolderName: "Downloads",
                selectedDisplayNames: ["Plan.md"],
                viewMode: .icon,
                previewScale: 1.35,
                sortOption: .dateModified,
                sortDirection: .descending,
                outputFilename: "02-live-folder-switching.png"
            )
        case .listView:
            return Descriptor(
                folderNames: ["Screenshots", "Downloads", "Workspace"],
                selectedFolderName: "Downloads",
                selectedDisplayNames: ["Plan.md"],
                viewMode: .list,
                previewScale: 1.0,
                sortOption: .dateModified,
                sortDirection: .descending,
                outputFilename: "03-live-list-view.png"
            )
        case .hierarchyView:
            return Descriptor(
                folderNames: ["Screenshots", "Downloads", "Workspace"],
                selectedFolderName: "Workspace",
                selectedDisplayNames: ["Assets"],
                viewMode: .hierarchy,
                previewScale: 1.0,
                sortOption: .kind,
                sortDirection: .ascending,
                outputFilename: "04-live-hierarchy-view.png"
            )
        }
    }
}

struct ScreenshotCaptureConfiguration {
    let fixtureRoot: URL
    let outputURL: URL
    let scene: ScreenshotScene

    static func fromEnvironment() -> ScreenshotCaptureConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FILE_STACK_SCREENSHOT_MODE"] == "1" else {
            return nil
        }
        guard
            let fixturePath = environment["FILE_STACK_SCREENSHOT_FIXTURE_ROOT"],
            let outputPath = environment["FILE_STACK_SCREENSHOT_OUTPUT_PATH"],
            let sceneValue = environment["FILE_STACK_SCREENSHOT_SCENE"],
            let scene = ScreenshotScene(rawValue: sceneValue)
        else {
            return nil
        }

        return ScreenshotCaptureConfiguration(
            fixtureRoot: URL(fileURLWithPath: fixturePath),
            outputURL: URL(fileURLWithPath: outputPath),
            scene: scene
        )
    }
}

final class ScreenshotAppDelegate: NSObject, NSApplicationDelegate {
    private let configuration: ScreenshotCaptureConfiguration
    private let controller = FileStackController(loadPersistedState: false)
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var backdropWindows: [NSWindow] = []

    init(configuration: ScreenshotCaptureConfiguration) {
        self.configuration = configuration
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let descriptor = configuration.scene.descriptor
        let folderURLs = descriptor.folderNames.map {
            configuration.fixtureRoot.appendingPathComponent($0, isDirectory: true)
        }
        let selectedFolderURL = configuration.fixtureRoot.appendingPathComponent(descriptor.selectedFolderName, isDirectory: true)

        controller.configurePreview(
            folders: folderURLs,
            selectedFolderURL: selectedFolderURL,
            viewMode: descriptor.viewMode,
            previewScale: descriptor.previewScale,
            sortOption: descriptor.sortOption,
            sortDirection: descriptor.sortDirection,
            selectedDisplayNames: descriptor.selectedDisplayNames
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Stashbar")
            button.appearance = NSAppearance(named: .aqua)
        }

        // Cover every screen with a gradient backdrop so the desktop wallpaper
        // never shows through during capture. We deliberately oversize each
        // window because borderless windows can otherwise be clipped by the
        // OS in subtle ways (Dock, notch, multi-display gaps).
        backdropWindows = NSScreen.screens.map { screen in
            let window = makeBackdropWindow(on: screen)
            window.orderFrontRegardless()
            return window
        }

        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller))
        popover.contentViewController?.view.appearance = NSAppearance(named: .aqua)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showPopoverAndCapture()
        }
    }

    private func showPopoverAndCapture() {
        guard let button = statusItem?.button else {
            NSApp.terminate(nil)
            return
        }

        controller.setInterfaceActive(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        positionPopover(relativeTo: button)
        popover.contentViewController?.view.window?.appearance = NSAppearance(named: .aqua)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.captureAndTerminate(relativeTo: button)
        }
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

    private func captureAndTerminate(relativeTo button: NSStatusBarButton) {
        defer { NSApp.terminate(nil) }

        guard
            let screen = button.window?.screen ?? NSScreen.main,
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let fullDisplayImage = CGDisplayCreateImage(displayID)
        else {
            fputs("error: unable to access screen for screenshot\n", stderr)
            return
        }

        let captureRect = targetCaptureRect(for: screen, anchor: button)
        let pixelRect = pixelRectForCapture(captureRect, on: screen, imageWidth: fullDisplayImage.width, imageHeight: fullDisplayImage.height)

        guard let cropped = fullDisplayImage.cropping(to: pixelRect) else {
            fputs("error: unable to crop screenshot area\n", stderr)
            return
        }

        let image = NSImage(cgImage: cropped, size: NSSize(width: captureRect.width, height: captureRect.height))

        do {
            try savePNG(image: image, to: configuration.outputURL, pixelSize: NSSize(width: 2560, height: 1600))
        } catch {
            fputs("error: failed to write screenshot - \(error)\n", stderr)
        }
    }

    private func targetCaptureRect(for screen: NSScreen, anchor button: NSStatusBarButton) -> CGRect {
        let screenFrame = screen.frame
        let desiredSize = CGSize(width: 1120, height: 720)
        // topInset = 0 captures from the very top of the screen so the menu bar
        // and our status item icon are visible in the screenshot.
        let topInset: CGFloat = 0

        let anchorRect: CGRect
        if let buttonWindow = button.window {
            let buttonBoundsInWindow = button.convert(button.bounds, to: nil)
            anchorRect = buttonWindow.convertToScreen(buttonBoundsInWindow)
        } else {
            anchorRect = CGRect(x: screenFrame.midX - 20, y: screenFrame.maxY - 28, width: 40, height: 20)
        }

        var originX = anchorRect.midX - desiredSize.width / 2
        let maxX = screenFrame.maxX - desiredSize.width
        originX = min(max(originX, screenFrame.minX), maxX)

        return CGRect(
            x: originX,
            y: screenFrame.maxY - desiredSize.height - topInset,
            width: desiredSize.width,
            height: desiredSize.height
        )
    }

    private func pixelRectForCapture(_ rect: CGRect, on screen: NSScreen, imageWidth: Int, imageHeight: Int) -> CGRect {
        let screenFrame = screen.frame
        let scaleX = CGFloat(imageWidth) / screenFrame.width
        let scaleY = CGFloat(imageHeight) / screenFrame.height

        let x = (rect.minX - screenFrame.minX) * scaleX
        let y = (screenFrame.maxY - rect.maxY) * scaleY
        let width = rect.width * scaleX
        let height = rect.height * scaleY

        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func savePNG(image: NSImage, to url: URL, pixelSize: NSSize) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "ScreenshotCapture", code: 1)
        }

        bitmap.size = pixelSize

        NSGraphicsContext.saveGraphicsState()
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "ScreenshotCapture", code: 2)
        }
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: pixelSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ScreenshotCapture", code: 3)
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try pngData.write(to: url)
    }

    private func makeBackdropWindow(on screen: NSScreen) -> NSWindow {
        // Oversize the frame so the window definitely covers the entire screen
        // even if the OS clamps borderless windows around Dock/notch/visible area.
        let screenFrame = screen.frame
        let oversizedFrame = screenFrame.insetBy(dx: -200, dy: -200)
        let window = NSWindow(
            contentRect: oversizedFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = true
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary, .stationary]
        window.appearance = NSAppearance(named: .aqua)
        let view = ScreenshotBackdropView()
        window.contentView = view
        window.setFrame(oversizedFrame, display: true)
        return window
    }
}

private final class ScreenshotBackdropView: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Soft, neutral gradient that complements the popover chrome without
        // competing with it for attention.
        let topColor = NSColor(srgbRed: 0.94, green: 0.96, blue: 0.99, alpha: 1.0)
        let bottomColor = NSColor(srgbRed: 0.74, green: 0.83, blue: 0.93, alpha: 1.0)
        if let gradient = NSGradient(starting: topColor, ending: bottomColor) {
            gradient.draw(in: bounds, angle: -90)
        }
    }
}
