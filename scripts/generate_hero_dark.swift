#!/usr/bin/env swift

import AppKit

let heroWidth: CGFloat = 1280
let heroHeight: CGFloat = 720
let heroSize = NSSize(width: heroWidth, height: heroHeight)

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_hero_dark.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]

// ── Helper: draw the dark icon into an NSImage (self-contained) ──
func makeDarkIcon(size: CGFloat) -> NSImage {
    let canvasSize = NSSize(width: size, height: size)
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to get graphics context")
    }

    let canvasRect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let center = CGPoint(x: size / 2, y: size / 2)

    // Dark background
    let backgroundColors = [
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.20, alpha: 1.0),
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.14, alpha: 1.0)
    ]
    if let gradient = NSGradient(colors: backgroundColors) {
        gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -90)
    }

    // Menu bar
    let menuBarWidth = size * 0.74
    let menuBarHeight = size * 0.12
    let menuBarRect = CGRect(
        x: center.x - menuBarWidth / 2,
        y: canvasRect.maxY - menuBarHeight - size * 0.11,
        width: menuBarWidth,
        height: menuBarHeight
    )
    let menuBarPath = NSBezierPath(roundedRect: nsRect(menuBarRect), xRadius: size * 0.06, yRadius: size * 0.06)
    NSColor(calibratedWhite: 0.92, alpha: 0.90).setFill()
    menuBarPath.fill()

    let menuItemRadius = size * 0.018
    let itemSpacing = size * 0.05
    let iconYOffset = menuBarRect.midY
    for index in 0..<4 {
        let x = menuBarRect.minX + itemSpacing * CGFloat(index + 1)
        let circleRect = CGRect(x: x - menuItemRadius, y: iconYOffset - menuItemRadius, width: menuItemRadius * 2, height: menuItemRadius * 2)
        let circlePath = NSBezierPath(ovalIn: nsRect(circleRect))
        (index == 3 ? NSColor(calibratedRed: 0.50, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(calibratedWhite: 0.65, alpha: 1.0)).setFill()
        circlePath.fill()
    }

    let menuHighlightWidth = size * 0.18
    let highlightRect = CGRect(
        x: menuBarRect.maxX - menuHighlightWidth - itemSpacing,
        y: iconYOffset - menuItemRadius * 2,
        width: menuHighlightWidth,
        height: menuItemRadius * 2.4
    )
    let highlightPath = NSBezierPath(roundedRect: nsRect(highlightRect), xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 0.85).setFill()
    highlightPath.fill()

    // Card stack
    let cardSpecs: [(CGSize, CGFloat, NSColor, NSColor, Bool)] = [
        (CGSize(width: -size * 0.137, height: -size * 0.205), -18,
         NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.35, alpha: 0.30),
         NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.15, alpha: 0.55), false),
        (CGSize(width: -size * 0.029, height: -size * 0.078), -8,
         NSColor(calibratedRed: 0.22, green: 0.30, blue: 0.42, alpha: 0.45),
         NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.18, alpha: 0.50), false),
        (CGSize(width: size * 0.117, height: size * 0.059), 6,
         NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.26, alpha: 1.0),
         NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.12, alpha: 0.45), true)
    ]

    let cardWidth = size * 0.72
    let cardHeight = size * 0.62
    let cardCorner = size * 0.09

    for (offset, rotation, fillColor, shadowColor, isTop) in cardSpecs {
        context.saveGState()
        context.translateBy(x: center.x + offset.width, y: center.y + offset.height)
        context.rotate(by: rotation * .pi / 180)

        let cardRect = CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight)
        let cardPath = NSBezierPath(roundedRect: nsRect(cardRect), xRadius: cardCorner, yRadius: cardCorner)

        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = size * 0.06
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.04)
        shadow.set()
        fillColor.setFill()
        cardPath.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        if isTop {
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
            NSColor(calibratedRed: 0.15, green: 0.40, blue: 0.88, alpha: 1.0).setFill()
            headerPath.fill()

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

            let menuStripHeight = headerHeight * 0.28
            let menuStripRect = CGRect(
                x: headerRect.minX + headerHeight * 0.3,
                y: headerRect.minY + headerHeight * 0.25,
                width: headerRect.width - headerHeight * 0.45,
                height: menuStripHeight
            )
            let menuStripPath = NSBezierPath(roundedRect: nsRect(menuStripRect), xRadius: menuStripHeight / 2, yRadius: menuStripHeight / 2)
            NSColor(calibratedWhite: 0.80, alpha: 0.45).setFill()
            menuStripPath.fill()

            let rows = 5
            let rowSpacing = cardHeight * 0.022
            let rowHeight = (contentRect.height - headerHeight - rowSpacing * CGFloat(rows + 1)) / CGFloat(rows)
            let rowWidth = contentRect.width
            for rowIndex in 0..<rows {
                let rowY = contentRect.minY + rowSpacing + CGFloat(rowIndex) * (rowHeight + rowSpacing)
                let rowRect = CGRect(x: contentRect.minX, y: rowY, width: rowWidth, height: rowHeight)
                let rowPath = NSBezierPath(roundedRect: nsRect(rowRect), xRadius: rowHeight / 2, yRadius: rowHeight / 2)
                let baseColor = NSColor(calibratedWhite: 0.20, alpha: 1.0)
                let highlightColor = NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.95, alpha: 1.0)
                (rowIndex == 2 ? highlightColor : baseColor).setFill()
                rowPath.fill()

                let indicatorWidth = rowWidth * 0.12
                let indicatorRect = CGRect(x: rowRect.minX + rowWidth * 0.04, y: rowRect.midY - rowHeight * 0.25, width: indicatorWidth, height: rowHeight * 0.5)
                let indicatorPath = NSBezierPath(roundedRect: nsRect(indicatorRect), xRadius: rowHeight * 0.25, yRadius: rowHeight * 0.25)
                (rowIndex == 2 ? NSColor(calibratedWhite: 0.90, alpha: 1.0) : NSColor(calibratedWhite: 0.45, alpha: 1.0)).setFill()
                indicatorPath.fill()
            }

            let badgeWidth = cardWidth * 0.28
            let badgeHeight = cardHeight * 0.16
            let badgeRect = CGRect(
                x: contentRect.maxX - badgeWidth,
                y: contentRect.minY - cardHeight * 0.04,
                width: badgeWidth,
                height: badgeHeight
            )
            let badgePath = NSBezierPath(roundedRect: nsRect(badgeRect), xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
            NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1.0).setFill()
            badgePath.fill()

            let text = "S" as NSString
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
    return image
}

// ── Begin hero composition ──
let heroImage = NSImage(size: heroSize)
heroImage.lockFocus()

guard NSGraphicsContext.current != nil else {
    fatalError("Unable to acquire graphics context")
}

let canvasRect = CGRect(origin: .zero, size: CGSize(width: heroWidth, height: heroHeight))

// Dark background gradient
if let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.14, alpha: 1.0),
    NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.28, alpha: 1.0)
]) {
    gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -35)
} else {
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.20, alpha: 1.0).setFill()
    NSBezierPath(rect: nsRect(canvasRect)).fill()
}

// Decorative wave overlay — adapted for dark tones
let wavePath = NSBezierPath()
wavePath.move(to: NSPoint(x: 0, y: heroHeight * 0.42))
wavePath.curve(to: NSPoint(x: heroWidth * 0.45, y: heroHeight * 0.60),
               controlPoint1: NSPoint(x: heroWidth * 0.18, y: heroHeight * 0.70),
               controlPoint2: NSPoint(x: heroWidth * 0.32, y: heroHeight * 0.45))
wavePath.curve(to: NSPoint(x: heroWidth, y: heroHeight * 0.52),
               controlPoint1: NSPoint(x: heroWidth * 0.65, y: heroHeight * 0.75),
               controlPoint2: NSPoint(x: heroWidth * 0.82, y: heroHeight * 0.62))
wavePath.line(to: NSPoint(x: heroWidth, y: heroHeight))
wavePath.line(to: NSPoint(x: 0, y: heroHeight))
wavePath.close()

NSColor(calibratedRed: 0.18, green: 0.30, blue: 0.50, alpha: 0.15).setFill()
wavePath.fill()

// Menu bar hint ribbon
let ribbonWidth = heroWidth * 0.62
let ribbonHeight = heroHeight * 0.11
let ribbonRect = CGRect(
    x: heroWidth * 0.08,
    y: heroHeight - ribbonHeight - heroHeight * 0.08,
    width: ribbonWidth,
    height: ribbonHeight
)

let ribbonPath = NSBezierPath(roundedRect: nsRect(ribbonRect), xRadius: ribbonHeight / 2, yRadius: ribbonHeight / 2)
NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
ribbonPath.fill()

// Icon with shadow — drawn inline, self-contained
let iconSizeTarget = NSSize(width: 180, height: 180)
let iconRect = CGRect(
    x: heroWidth * 0.10,
    y: heroHeight - iconSizeTarget.height - heroHeight * 0.22,
    width: iconSizeTarget.width,
    height: iconSizeTarget.height
)

let darkIcon = makeDarkIcon(size: 1024)

let iconShadow = NSShadow()
iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.50)
iconShadow.shadowBlurRadius = 24
iconShadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.current?.saveGraphicsState()
iconShadow.set()
darkIcon.draw(in: nsRect(iconRect), from: NSRect(origin: .zero, size: darkIcon.size), operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: nil)
NSGraphicsContext.current?.restoreGraphicsState()

// Headline and subcopy — light text on dark background
let headline = "Stashbar"
let subCopy = "원하는 폴더를 메뉴바에 고정해 언제든 바로 열람"
let bulletCopy = "폴더별 최신 파일 · 퀵 룩 · 복사/붙여넣기까지 한 번에"

let headlineAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 70, weight: .bold),
    .foregroundColor: NSColor.white
]

let subAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1.0)
]

let bulletAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1.0)
]

let textOriginX = iconRect.maxX + heroWidth * 0.035
let headlineOriginY = iconRect.maxY + 20

(headline as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY), withAttributes: headlineAttributes)
(subCopy as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY - 70), withAttributes: subAttributes)
(bulletCopy as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY - 118), withAttributes: bulletAttributes)

// Screenshot card — self-contained mock file list preview
let cardWidth = heroWidth * 0.40
let cardHeight = heroHeight * 0.58
let cardRect = CGRect(
    x: heroWidth - cardWidth - heroWidth * 0.08,
    y: heroHeight * 0.04,
    width: cardWidth,
    height: cardHeight
)

let cardPath = NSBezierPath(roundedRect: nsRect(cardRect), xRadius: 36, yRadius: 36)

let cardShadow = NSShadow()
cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
cardShadow.shadowBlurRadius = 32
cardShadow.shadowOffset = NSSize(width: 0, height: -24)

NSGraphicsContext.current?.saveGraphicsState()
cardShadow.set()
NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.24, alpha: 0.98).setFill()
cardPath.fill()
NSGraphicsContext.current?.restoreGraphicsState()

// Mock file list inside card
let inset: CGFloat = 32
let innerRect = CGRect(
    x: cardRect.minX + inset,
    y: cardRect.minY + inset,
    width: cardRect.width - inset * 2,
    height: cardRect.height - inset * 2
)

// Header bar
let mockHeaderHeight: CGFloat = 42
let mockHeaderRect = CGRect(
    x: innerRect.minX,
    y: innerRect.maxY - mockHeaderHeight,
    width: innerRect.width,
    height: mockHeaderHeight
)
let mockHeaderPath = NSBezierPath(roundedRect: nsRect(mockHeaderRect), xRadius: 12, yRadius: 12)
NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.85, alpha: 1.0).setFill()
mockHeaderPath.fill()

// Traffic lights
let mockLightRadius: CGFloat = 7
let mockLightY = mockHeaderRect.midY
let mockLightSpacing: CGFloat = 22
let mockStartX = mockHeaderRect.minX + 20
let mockLightColors: [NSColor] = [
    NSColor(calibratedRed: 0.99, green: 0.29, blue: 0.27, alpha: 1.0),
    NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.26, alpha: 1.0),
    NSColor(calibratedRed: 0.32, green: 0.81, blue: 0.39, alpha: 1.0)
]
for (index, color) in mockLightColors.enumerated() {
    let x = mockStartX + CGFloat(index) * mockLightSpacing
    let circleRect = CGRect(x: x - mockLightRadius, y: mockLightY - mockLightRadius, width: mockLightRadius * 2, height: mockLightRadius * 2)
    let circlePath = NSBezierPath(ovalIn: nsRect(circleRect))
    color.setFill()
    circlePath.fill()
}

// File list rows
let mockRows = 6
let mockRowSpacing: CGFloat = 10
let mockRowHeight = (innerRect.height - mockHeaderHeight - mockRowSpacing * CGFloat(mockRows + 1) - 20) / CGFloat(mockRows)
let fileNames = ["project_docs", "screenshots", "design_assets", "exports", "archive_2025", "temp_files"]
let dateLabels = ["May 6", "May 7", "May 8", "May 8", "May 9", "May 9"]

for rowIndex in 0..<mockRows {
    let rowY = innerRect.minY + mockRowSpacing + CGFloat(rowIndex) * (mockRowHeight + mockRowSpacing) + 10
    let rowRect = CGRect(x: innerRect.minX, y: rowY, width: innerRect.width, height: mockRowHeight)
    let rowPath = NSBezierPath(roundedRect: nsRect(rowRect), xRadius: mockRowHeight / 2, yRadius: mockRowHeight / 2)
    let isSelected = rowIndex == 2
    let rowColor = isSelected
        ? NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.95, alpha: 1.0)
        : NSColor(calibratedWhite: 0.22, alpha: 1.0)
    rowColor.setFill()
    rowPath.fill()

    // File name label
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: isSelected ? NSColor.white : NSColor(calibratedWhite: 0.75, alpha: 1.0)
    ]
    let labelPoint = NSPoint(x: rowRect.minX + 16, y: rowRect.midY - 8)
    (fileNames[rowIndex] as NSString).draw(at: labelPoint, withAttributes: labelAttributes)

    // Date label
    let dateAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
        .foregroundColor: isSelected
            ? NSColor(calibratedWhite: 0.90, alpha: 1.0)
            : NSColor(calibratedWhite: 0.55, alpha: 1.0)
    ]
    let datePoint = NSPoint(x: rowRect.maxX - 60, y: rowRect.midY - 7)
    (dateLabels[rowIndex] as NSString).draw(at: datePoint, withAttributes: dateAttributes)
}

// Caption tag on card
let caption = "최근 파일·스크린샷을 자동으로 모아주는 미니 대시보드"
let captionAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.65, alpha: 1.0)
]
let captionPoint = NSPoint(x: cardRect.minX + inset, y: cardRect.minY + inset / 2)
(caption as NSString).draw(at: captionPoint, withAttributes: captionAttributes)

heroImage.unlockFocus()

guard let tiffData = heroImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to create PNG")
}

let outputURL = URL(fileURLWithPath: outputPath)
do {
    try pngData.write(to: outputURL)
} catch {
    fputs("error: failed to write hero image - \(error)\n", stderr)
    exit(1)
}
