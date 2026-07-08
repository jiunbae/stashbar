#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_demo_fixture_assets.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)

struct DemoAsset {
    let filename: String
    let title: String
    let subtitle: String
    let accent: NSColor
    let secondary: NSColor
}

let assets: [DemoAsset] = [
    DemoAsset(
        filename: "Cover.png",
        title: "Stashbar Board",
        subtitle: "Recent files and release flow",
        accent: NSColor(calibratedRed: 0.42, green: 0.56, blue: 0.65, alpha: 1.0),
        secondary: NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.92, alpha: 1.0)
    ),
    DemoAsset(
        filename: "Card.jpg",
        title: "Folder Flow",
        subtitle: "Pinned workspace folders",
        accent: NSColor(calibratedRed: 0.25, green: 0.33, blue: 0.39, alpha: 1.0),
        secondary: NSColor(calibratedRed: 0.82, green: 0.86, blue: 0.89, alpha: 1.0)
    ),
    DemoAsset(
        filename: "Stats.png",
        title: "Local Snapshot",
        subtitle: "Everything stays on this Mac",
        accent: NSColor(calibratedRed: 0.69, green: 0.56, blue: 0.38, alpha: 1.0),
        secondary: NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.78, alpha: 1.0)
    )
]

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

func saveImage(_ image: NSImage, to url: URL, type: NSBitmapImageRep.FileType) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: type, properties: [:]) else {
        throw NSError(domain: "DemoAssetGeneration", code: 1)
    }
    try data.write(to: url)
}

for asset in assets {
    let size = NSSize(width: 1400, height: 900)
    let image = NSImage(size: size)
    image.lockFocus()

    let canvasRect = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
    if let gradient = NSGradient(colors: [asset.secondary, .white]) {
        gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -32)
    }

    let cardRect = CGRect(x: 88, y: 120, width: 1224, height: 640)
    let cardShadow = NSShadow()
    cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    cardShadow.shadowBlurRadius = 24
    cardShadow.shadowOffset = NSSize(width: 0, height: -14)

    NSGraphicsContext.current?.saveGraphicsState()
    cardShadow.set()
    let cardPath = NSBezierPath(roundedRect: nsRect(cardRect), xRadius: 42, yRadius: 42)
    NSColor.white.setFill()
    cardPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let bannerRect = CGRect(x: cardRect.minX + 54, y: cardRect.maxY - 154, width: 1116, height: 92)
    let bannerPath = NSBezierPath(roundedRect: nsRect(bannerRect), xRadius: 28, yRadius: 28)
    asset.accent.withAlphaComponent(0.92).setFill()
    bannerPath.fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 54, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.28, alpha: 1.0)
    ]
    let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: asset.accent
    ]

    (asset.title as NSString).draw(at: CGPoint(x: bannerRect.minX + 34, y: bannerRect.minY + 18), withAttributes: titleAttributes)
    (asset.subtitle as NSString).draw(at: CGPoint(x: cardRect.minX + 60, y: cardRect.maxY - 224), withAttributes: subtitleAttributes)

    let leftGraphRect = CGRect(x: cardRect.minX + 60, y: cardRect.minY + 86, width: 420, height: 270)
    let rightGraphRect = CGRect(x: cardRect.minX + 540, y: cardRect.minY + 86, width: 630, height: 270)

    drawSection(title: "Weekly Focus", rect: leftGraphRect, accent: asset.accent, secondary: asset.secondary, attributes: sectionTitleAttributes)
    drawBars(in: leftGraphRect.insetBy(dx: 30, dy: 46), accent: asset.accent)

    drawSection(title: "Release Tasks", rect: rightGraphRect, accent: asset.accent, secondary: asset.secondary, attributes: sectionTitleAttributes)
    drawChecklist(in: rightGraphRect.insetBy(dx: 30, dy: 42), accent: asset.accent)

    image.unlockFocus()

    let outputURL = outputDirectory.appendingPathComponent(asset.filename)
    let type: NSBitmapImageRep.FileType = asset.filename.hasSuffix(".jpg") ? .jpeg : .png
    try saveImage(image, to: outputURL, type: type)
}

func drawSection(title: String, rect: CGRect, accent: NSColor, secondary: NSColor, attributes: [NSAttributedString.Key: Any]) {
    let background = NSBezierPath(roundedRect: nsRect(rect), xRadius: 28, yRadius: 28)
    secondary.withAlphaComponent(0.28).setFill()
    background.fill()
    (title as NSString).draw(at: CGPoint(x: rect.minX + 22, y: rect.maxY - 38), withAttributes: attributes)
}

func drawBars(in rect: CGRect, accent: NSColor) {
    let values: [CGFloat] = [0.42, 0.68, 0.54, 0.88, 0.74]
    let spacing: CGFloat = 18
    let barWidth = (rect.width - spacing * CGFloat(values.count - 1)) / CGFloat(values.count)

    for (index, value) in values.enumerated() {
        let x = rect.minX + CGFloat(index) * (barWidth + spacing)
        let barHeight = rect.height * value
        let barRect = CGRect(x: x, y: rect.minY, width: barWidth, height: barHeight)
        let path = NSBezierPath(roundedRect: nsRect(barRect), xRadius: 14, yRadius: 14)
        accent.withAlphaComponent(0.2 + 0.14 * CGFloat(index)).setFill()
        path.fill()
    }
}

func drawChecklist(in rect: CGRect, accent: NSColor) {
    let rowHeight: CGFloat = 42
    let rowSpacing: CGFloat = 18
    let rows = [
        "Screenshot set finalized",
        "Metadata localized",
        "Build uploaded to ASC",
        "Review notes prepared"
    ]

    for (index, row) in rows.enumerated() {
        let y = rect.maxY - CGFloat(index + 1) * rowHeight - CGFloat(index) * rowSpacing
        let rowRect = CGRect(x: rect.minX, y: y, width: rect.width, height: rowHeight)
        let path = NSBezierPath(roundedRect: nsRect(rowRect), xRadius: 16, yRadius: 16)
        accent.withAlphaComponent(index == 0 ? 0.20 : 0.10).setFill()
        path.fill()

        let circleRect = CGRect(x: rowRect.minX + 18, y: rowRect.minY + 11, width: 20, height: 20)
        let circle = NSBezierPath(ovalIn: nsRect(circleRect))
        accent.setFill()
        circle.fill()

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 21, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.22, alpha: 1.0)
        ]
        (row as NSString).draw(at: CGPoint(x: rowRect.minX + 54, y: rowRect.minY + 8), withAttributes: textAttributes)
    }
}
