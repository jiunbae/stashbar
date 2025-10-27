#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let iconSize: CGFloat = 1024
let canvasSize = NSSize(width: iconSize, height: iconSize)

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to get graphics context")
}

let canvasRect = CGRect(origin: .zero, size: CGSize(width: iconSize, height: iconSize))
let center = CGPoint(x: iconSize / 2, y: iconSize / 2)

// Background
let backgroundColors = [
    NSColor(calibratedRed: 0.945, green: 0.965, blue: 0.995, alpha: 1.0),
    NSColor(calibratedRed: 0.905, green: 0.935, blue: 0.995, alpha: 1.0)
]
if let gradient = NSGradient(colors: backgroundColors) {
    gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -90)
} else {
    NSColor.white.setFill()
    NSBezierPath(rect: nsRect(canvasRect)).fill()
}

// Menu bar indicator to communicate menu-bar workflow
let menuBarWidth = iconSize * 0.74
let menuBarHeight = iconSize * 0.12
let menuBarRect = CGRect(
    x: center.x - menuBarWidth / 2,
    y: canvasRect.maxY - menuBarHeight - iconSize * 0.11,
    width: menuBarWidth,
    height: menuBarHeight
)

let menuBarPath = NSBezierPath(roundedRect: nsRect(menuBarRect), xRadius: iconSize * 0.06, yRadius: iconSize * 0.06)
NSColor(calibratedWhite: 0.12, alpha: 0.88).setFill()
menuBarPath.fill()

let menuItemRadius = iconSize * 0.018
let itemSpacing = iconSize * 0.05
let iconYOffset = menuBarRect.midY

for index in 0..<4 {
    let x = menuBarRect.minX + itemSpacing * CGFloat(index + 1)
    let circleRect = CGRect(x: x - menuItemRadius, y: iconYOffset - menuItemRadius, width: menuItemRadius * 2, height: menuItemRadius * 2)
    let circlePath = NSBezierPath(ovalIn: nsRect(circleRect))
    (index == 3 ? NSColor.systemBlue : NSColor(calibratedWhite: 0.7, alpha: 1.0)).setFill()
    circlePath.fill()
}

let menuHighlightWidth = iconSize * 0.18
let highlightRect = CGRect(
    x: menuBarRect.maxX - menuHighlightWidth - itemSpacing,
    y: iconYOffset - menuItemRadius * 2,
    width: menuHighlightWidth,
    height: menuItemRadius * 2.4
)
let highlightPath = NSBezierPath(roundedRect: nsRect(highlightRect), xRadius: iconSize * 0.02, yRadius: iconSize * 0.02)
NSColor(calibratedRed: 0.32, green: 0.58, blue: 1.0, alpha: 1.0).setFill()
highlightPath.fill()

// Card stack parameters resembling perspective stack
struct CardSpec {
    let offset: CGSize
    let rotation: CGFloat
    let fillColor: NSColor
    let shadowColor: NSColor
    let isTop: Bool
}

let cardSpecs: [CardSpec] = [
    CardSpec(
        offset: CGSize(width: -140, height: -210),
        rotation: -18,
        fillColor: NSColor(calibratedRed: 0.48, green: 0.68, blue: 1.0, alpha: 0.25),
        shadowColor: NSColor(calibratedRed: 0.17, green: 0.34, blue: 0.82, alpha: 0.4),
        isTop: false
    ),
    CardSpec(
        offset: CGSize(width: -30, height: -80),
        rotation: -8,
        fillColor: NSColor(calibratedRed: 0.32, green: 0.56, blue: 1.0, alpha: 0.45),
        shadowColor: NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.75, alpha: 0.45),
        isTop: false
    ),
    CardSpec(
        offset: CGSize(width: 120, height: 60),
        rotation: 6,
        fillColor: NSColor.white,
        shadowColor: NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.62, alpha: 0.35),
        isTop: true
    )
]

let cardWidth = iconSize * 0.72
let cardHeight = iconSize * 0.62
let cardCorner = iconSize * 0.09

for spec in cardSpecs {
    context.saveGState()
    context.translateBy(x: center.x + spec.offset.width, y: center.y + spec.offset.height)
    context.rotate(by: spec.rotation * .pi / 180)

    let cardRect = CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight)
    let cardPath = NSBezierPath(roundedRect: nsRect(cardRect), xRadius: cardCorner, yRadius: cardCorner)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = spec.shadowColor
    shadow.shadowBlurRadius = iconSize * 0.06
    shadow.shadowOffset = NSSize(width: 0, height: -iconSize * 0.04)
    shadow.set()
    spec.fillColor.setFill()
    cardPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    if spec.isTop {
        // Finder-like header
        let contentInset = cardWidth * 0.08
        let contentRect = cardRect.insetBy(dx: contentInset, dy: contentInset)
        let headerHeight = cardHeight * 0.20
        let headerRect = CGRect(
            x: contentRect.minX,
            y: contentRect.maxY - headerHeight,
            width: contentRect.width,
            height: headerHeight
        )

        let headerPath = NSBezierPath(roundedRect: nsRect(headerRect), xRadius: cardCorner * 0.6, yRadius: cardCorner * 0.6)
        NSColor(calibratedRed: 0.09, green: 0.32, blue: 0.82, alpha: 1.0).setFill()
        headerPath.fill()

        // Traffic lights
        let lightRadius = headerHeight * 0.18
        let lightY = headerRect.maxY - headerHeight * 0.5
        let lightSpacing = lightRadius * 2.4
        let startX = headerRect.minX + lightSpacing
        let lightColors: [NSColor] = [
            NSColor(calibratedRed: 0.99, green: 0.29, blue: 0.27, alpha: 1.0),
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.26, alpha: 1.0),
            NSColor(calibratedRed: 0.32, green: 0.81, blue: 0.39, alpha: 1.0)
        ]
        for (index, color) in lightColors.enumerated() {
            let x = startX + CGFloat(index) * lightSpacing
            let circleRect = CGRect(x: x - lightRadius, y: lightY - lightRadius, width: lightRadius * 2, height: lightRadius * 2)
            let circlePath = NSBezierPath(ovalIn: nsRect(circleRect))
            color.setFill()
            circlePath.fill()
        }

        // Menu bar strip inside window
        let menuStripHeight = headerHeight * 0.28
        let menuStripRect = CGRect(
            x: headerRect.minX + headerHeight * 0.3,
            y: headerRect.minY + headerHeight * 0.25,
            width: headerRect.width - headerHeight * 0.45,
            height: menuStripHeight
        )
        let menuStripPath = NSBezierPath(roundedRect: nsRect(menuStripRect), xRadius: menuStripHeight / 2, yRadius: menuStripHeight / 2)
        NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.94, alpha: 1.0).withAlphaComponent(0.55).setFill()
        menuStripPath.fill()

        // File list rows
        let rows = 5
        let rowSpacing = cardHeight * 0.022
        let rowHeight = (contentRect.height - headerHeight - rowSpacing * CGFloat(rows + 1)) / CGFloat(rows)
        let rowWidth = contentRect.width
        for rowIndex in 0..<rows {
            let rowY = contentRect.minY + rowSpacing + CGFloat(rowIndex) * (rowHeight + rowSpacing)
            let rowRect = CGRect(x: contentRect.minX, y: rowY, width: rowWidth, height: rowHeight)
            let rowPath = NSBezierPath(roundedRect: nsRect(rowRect), xRadius: rowHeight / 2, yRadius: rowHeight / 2)
            let baseColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
            let highlightColor = NSColor(calibratedRed: 0.30, green: 0.58, blue: 1.0, alpha: 1.0)
            (rowIndex == 2 ? highlightColor : baseColor).setFill()
            rowPath.fill()

            let indicatorWidth = rowWidth * 0.12
            let indicatorRect = CGRect(x: rowRect.minX + rowWidth * 0.04, y: rowRect.midY - rowHeight * 0.25, width: indicatorWidth, height: rowHeight * 0.5)
            let indicatorPath = NSBezierPath(roundedRect: nsRect(indicatorRect), xRadius: rowHeight * 0.25, yRadius: rowHeight * 0.25)
            (rowIndex == 2 ? NSColor.white : NSColor(calibratedWhite: 0.78, alpha: 1.0)).setFill()
            indicatorPath.fill()
        }

        // FS badge to emphasise brand
        let badgeWidth = cardWidth * 0.28
        let badgeHeight = cardHeight * 0.16
        let badgeRect = CGRect(
            x: contentRect.maxX - badgeWidth,
            y: contentRect.minY - cardHeight * 0.04,
            width: badgeWidth,
            height: badgeHeight
        )
        let badgePath = NSBezierPath(roundedRect: nsRect(badgeRect), xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
        let badgeColor = NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.98, alpha: 1.0)
        badgeColor.setFill()
        badgePath.fill()

        let text = "FS" as NSString
        let badgeFont = NSFont.systemFont(ofSize: badgeHeight * 0.7, weight: .heavy)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let textRect = CGRect(
            x: badgeRect.minX,
            y: badgeRect.minY + badgeHeight * 0.08,
            width: badgeWidth,
            height: badgeHeight * 0.84
        )
        text.draw(in: textRect, withAttributes: textAttributes)
    }

    context.restoreGState()
}

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
