import AppKit

enum StashbarBrand {
    /// A compact, monochrome version of the app mark designed for the 18 pt menu bar.
    static func statusItemImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()

            // Two staggered recent-file cards.
            NSBezierPath(roundedRect: NSRect(x: 5.0, y: 11.8, width: 7.5, height: 2.1), xRadius: 0.9, yRadius: 0.9).fill()
            NSBezierPath(roundedRect: NSRect(x: 6.8, y: 14.5, width: 6.2, height: 1.7), xRadius: 0.7, yRadius: 0.7).fill()

            // The pocket uses the same soft central notch as the full app icon.
            let tray = NSBezierPath()
            tray.move(to: NSPoint(x: 3.2, y: 10.5))
            tray.line(to: NSPoint(x: 6.4, y: 10.5))
            tray.curve(
                to: NSPoint(x: 9, y: 8.2),
                controlPoint1: NSPoint(x: 7.4, y: 10.5),
                controlPoint2: NSPoint(x: 7.6, y: 8.2)
            )
            tray.curve(
                to: NSPoint(x: 11.6, y: 10.5),
                controlPoint1: NSPoint(x: 10.4, y: 8.2),
                controlPoint2: NSPoint(x: 10.6, y: 10.5)
            )
            tray.line(to: NSPoint(x: 14.8, y: 10.5))
            tray.curve(to: NSPoint(x: 16, y: 9.3), controlPoint1: NSPoint(x: 15.5, y: 10.5), controlPoint2: NSPoint(x: 16, y: 10))
            tray.line(to: NSPoint(x: 16, y: 4.1))
            tray.curve(to: NSPoint(x: 14.4, y: 2.5), controlPoint1: NSPoint(x: 16, y: 3.2), controlPoint2: NSPoint(x: 15.3, y: 2.5))
            tray.line(to: NSPoint(x: 3.6, y: 2.5))
            tray.curve(to: NSPoint(x: 2, y: 4.1), controlPoint1: NSPoint(x: 2.7, y: 2.5), controlPoint2: NSPoint(x: 2, y: 3.2))
            tray.line(to: NSPoint(x: 2, y: 9.3))
            tray.curve(to: NSPoint(x: 3.2, y: 10.5), controlPoint1: NSPoint(x: 2, y: 10), controlPoint2: NSPoint(x: 2.5, y: 10.5))
            tray.close()
            tray.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Stashbar"
        return image
    }
}
