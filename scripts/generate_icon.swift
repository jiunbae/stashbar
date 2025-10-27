#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let iconSize: CGFloat = 1024
let size = NSSize(width: iconSize, height: iconSize)

let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to get graphics context")
}

let rect = CGRect(origin: .zero, size: CGSize(width: iconSize, height: iconSize))
NSColor.white.setFill()
context.fill(rect)

let inset: CGFloat = iconSize * 0.18
let stackRect = rect.insetBy(dx: inset, dy: inset)
let stackPath = NSBezierPath(roundedRect: NSRect(x: stackRect.origin.x, y: stackRect.origin.y, width: stackRect.width, height: stackRect.height), xRadius: iconSize * 0.08, yRadius: iconSize * 0.08)
NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.95, alpha: 0.18).setFill()
stackPath.fill()

let middleInset = inset * 0.6
let middleRect = rect.insetBy(dx: middleInset, dy: middleInset + iconSize * 0.05)
let middlePath = NSBezierPath(roundedRect: NSRect(x: middleRect.origin.x, y: middleRect.origin.y, width: middleRect.width, height: middleRect.height), xRadius: iconSize * 0.06, yRadius: iconSize * 0.06)
NSColor(calibratedRed: 0.17, green: 0.47, blue: 0.98, alpha: 0.55).setFill()
middlePath.fill()

let topInset = inset * 0.45
let topRect = rect.insetBy(dx: topInset, dy: topInset + iconSize * 0.18)
let topPath = NSBezierPath(roundedRect: NSRect(x: topRect.origin.x, y: topRect.origin.y, width: topRect.width, height: topRect.height), xRadius: iconSize * 0.05, yRadius: iconSize * 0.05)
NSColor(calibratedRed: 0.21, green: 0.5, blue: 0.99, alpha: 0.92).setFill()
topPath.fill()

let accent = NSColor(calibratedRed: 0.04, green: 0.31, blue: 0.78, alpha: 1.0)
accent.withAlphaComponent(0.18).setStroke()
topPath.lineWidth = iconSize * 0.012
topPath.stroke()

let text = "FS" as NSString
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let fontSize = iconSize * 0.42
let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = iconSize * 0.05
shadow.shadowOffset = NSSize(width: 0, height: -iconSize * 0.03)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: accent,
    .paragraphStyle: paragraph,
    .shadow: shadow
]

let textRect = CGRect(x: rect.midX - iconSize * 0.35, y: rect.midY - fontSize * 0.55, width: iconSize * 0.7, height: fontSize * 1.1)
text.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to create PNG data")
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("error: failed to write icon png - \(error)\n", stderr)
    exit(1)
}
