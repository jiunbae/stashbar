#!/usr/bin/env swift

import AppKit

let heroWidth: CGFloat = 1280
let heroHeight: CGFloat = 720
let heroSize = NSSize(width: heroWidth, height: heroHeight)

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_hero.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = projectRoot.appendingPathComponent("Resources", isDirectory: true)

let iconURL = resourcesURL.appendingPathComponent("FileStackIcon.png")
let previewURL = resourcesURL.appendingPathComponent("preview.png")

guard let iconImage = NSImage(contentsOf: iconURL) else {
    fputs("error: FileStackIcon.png not found\n", stderr)
    exit(1)
}

guard let previewImage = NSImage(contentsOf: previewURL) else {
    fputs("error: preview.png not found\n", stderr)
    exit(1)
}

let heroImage = NSImage(size: heroSize)
heroImage.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to acquire graphics context")
}

let canvasRect = CGRect(origin: .zero, size: CGSize(width: heroWidth, height: heroHeight))

// Background gradient
if let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.55, alpha: 1.0),
    NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.83, alpha: 1.0)
]) {
    gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -35)
} else {
    NSColor(calibratedRed: 0.09, green: 0.30, blue: 0.75, alpha: 1.0).setFill()
    NSBezierPath(rect: nsRect(canvasRect)).fill()
}

// Decorative wave overlay
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

NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.66, alpha: 0.28).setFill()
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
NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
ribbonPath.fill()

// Icon with shadow
let iconSizeTarget = NSSize(width: 180, height: 180)
let iconRect = CGRect(
    x: heroWidth * 0.10,
    y: heroHeight - iconSizeTarget.height - heroHeight * 0.22,
    width: iconSizeTarget.width,
    height: iconSizeTarget.height
)

let iconShadow = NSShadow()
iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
iconShadow.shadowBlurRadius = 24
iconShadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.current?.saveGraphicsState()
iconShadow.set()
iconImage.size = iconSizeTarget
iconImage.draw(in: nsRect(iconRect), from: NSRect(origin: .zero, size: iconImage.size), operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: nil)
NSGraphicsContext.current?.restoreGraphicsState()

// Headline and subcopy
let headline = "Stashbar"
let subCopy = "원하는 폴더를 메뉴바에 고정해 언제든 바로 열람"
let bulletCopy = "폴더별 최신 파일 · 퀵 룩 · 복사/붙여넣기까지 한 번에"

let headlineAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 70, weight: .bold),
    .foregroundColor: NSColor.white
]

let subAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.93, alpha: 1.0)
]

let bulletAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1.0)
]

let textOriginX = iconRect.maxX + heroWidth * 0.035
let headlineOriginY = iconRect.maxY + 20

(headline as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY), withAttributes: headlineAttributes)
(subCopy as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY - 70), withAttributes: subAttributes)
(bulletCopy as NSString).draw(at: NSPoint(x: textOriginX, y: headlineOriginY - 118), withAttributes: bulletAttributes)

// Screenshot card
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
cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
cardShadow.shadowBlurRadius = 32
cardShadow.shadowOffset = NSSize(width: 0, height: -24)

NSGraphicsContext.current?.saveGraphicsState()
cardShadow.set()
NSColor(calibratedWhite: 0.98, alpha: 0.98).setFill()
cardPath.fill()
NSGraphicsContext.current?.restoreGraphicsState()

// Draw preview image inside card with inset and clipping
let inset: CGFloat = 32
let innerRect = CGRect(
    x: cardRect.minX + inset,
    y: cardRect.minY + inset,
    width: cardRect.width - inset * 2,
    height: cardRect.height - inset * 2
)

let clipPath = NSBezierPath(roundedRect: nsRect(innerRect), xRadius: 28, yRadius: 28)
clipPath.addClip()

let previewSize = previewImage.size
let previewAspect = previewSize.width / previewSize.height
let targetAspect = innerRect.width / innerRect.height
var drawRect = innerRect

if previewAspect > targetAspect {
    let scaledHeight = innerRect.width / previewAspect
    drawRect.origin.y += (innerRect.height - scaledHeight) / 2
    drawRect.size.height = scaledHeight
} else {
    let scaledWidth = innerRect.height * previewAspect
    drawRect.origin.x += (innerRect.width - scaledWidth) / 2
    drawRect.size.width = scaledWidth
}

previewImage.draw(in: nsRect(drawRect), from: nsRect(CGRect(origin: .zero, size: previewSize)), operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: nil)
NSGraphicsContext.current?.restoreGraphicsState()

// Small caption tag on card
let caption = "최근 파일·스크린샷을 자동으로 모아주는 미니 대시보드"
let captionAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.25, alpha: 1.0)
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
