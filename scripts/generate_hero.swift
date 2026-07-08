#!/usr/bin/env swift

import AppKit

let heroWidth: CGFloat = 2560
let heroHeight: CGFloat = 1440
let heroSize = NSSize(width: heroWidth, height: heroHeight)

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: nsRect(rect), xRadius: radius, yRadius: radius)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color fill: NSColor) {
    fill.setFill()
    rounded(rect, radius).fill()
}

func drawCapsule(_ rect: CGRect, fill: NSColor) {
    fillRounded(rect, radius: rect.height / 2, color: fill)
}

func drawShadowed(_ path: NSBezierPath, fill: NSColor, shadowColor: NSColor, blur: CGFloat, offset: CGSize) {
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: offset.width, height: offset.height)
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    fill.setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawMultilineText(_ text: String, rect: CGRect, font: NSFont, color: NSColor, lineHeight: CGFloat = 1.0) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineHeightMultiple = lineHeight
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let bounds = attributed.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
    attributed.draw(
        with: nsRect(CGRect(x: rect.minX, y: rect.maxY - bounds.height, width: rect.width, height: bounds.height)),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    return bounds.height
}

func aspectFitRect(for imageSize: NSSize, in target: CGRect) -> CGRect {
    let imageAspect = imageSize.width / imageSize.height
    let targetAspect = target.width / target.height
    var rect = target
    if imageAspect > targetAspect {
        rect.size.height = target.width / imageAspect
        rect.origin.y += (target.height - rect.height) / 2
    } else {
        rect.size.width = target.height * imageAspect
        rect.origin.x += (target.width - rect.width) / 2
    }
    return rect
}

func savePNG(_ image: NSImage, to url: URL, pixelSize: NSSize) throws {
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
        throw NSError(domain: "HeroGeneration", code: 1)
    }

    bitmap.size = pixelSize
    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "HeroGeneration", code: 2)
    }
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: pixelSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .sourceOver,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "HeroGeneration", code: 3)
    }
    try pngData.write(to: url)
}

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_hero.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = projectRoot.appendingPathComponent("Resources", isDirectory: true)

let iconCandidates = [
    resourcesURL.appendingPathComponent("StashbarIcon.png"),
    resourcesURL.appendingPathComponent("FileStackIcon.png")
]
guard let iconURL = iconCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
      let iconImage = NSImage(contentsOf: iconURL) else {
    fputs("error: StashbarIcon.png not found\n", stderr)
    exit(1)
}

let previewURL = resourcesURL.appendingPathComponent("preview.png")
guard let previewImage = NSImage(contentsOf: previewURL) else {
    fputs("error: preview.png not found\n", stderr)
    exit(1)
}

let heroImage = NSImage(size: heroSize)
heroImage.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to acquire graphics context")
}
NSGraphicsContext.current?.imageInterpolation = .high

let canvasRect = CGRect(origin: .zero, size: CGSize(width: heroWidth, height: heroHeight))

NSGradient(colors: [
    color(0.965, 0.961, 0.945),
    color(0.906, 0.925, 0.937)
], atLocations: [0, 1], colorSpace: .deviceRGB)?
    .draw(in: canvasRect, angle: -36)

context.saveGState()
for index in 0..<6 {
    let rect = CGRect(
        x: -heroWidth * 0.08,
        y: heroHeight * (0.07 + CGFloat(index) * 0.145),
        width: heroWidth * 1.16,
        height: heroHeight * 0.040
    )
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: -8 * .pi / 180)
    fillRounded(
        CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height),
        radius: rect.height / 2,
        color: index == 3 ? color(0.420, 0.561, 0.651, 0.18) : NSColor.white.withAlphaComponent(0.32)
    )
    context.restoreGState()
}
context.restoreGState()

let menuBarRect = CGRect(x: 140, y: heroHeight - 160, width: heroWidth - 280, height: 76)
drawShadowed(
    rounded(menuBarRect, 38),
    fill: color(0.169, 0.200, 0.227, 0.94),
    shadowColor: NSColor.black.withAlphaComponent(0.12),
    blur: 22,
    offset: CGSize(width: 0, height: -8)
)

let topIconRect = CGRect(x: menuBarRect.minX + 28, y: menuBarRect.midY - 24, width: 48, height: 48)
iconImage.draw(in: nsRect(topIconRect),
               from: NSRect(origin: .zero, size: iconImage.size),
               operation: .sourceOver,
               fraction: 1.0)

let menuLabelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.92)
]
("Stashbar" as NSString).draw(at: CGPoint(x: topIconRect.maxX + 18, y: menuBarRect.midY - 18), withAttributes: menuLabelAttributes)

let menuPills = ["Screenshots", "Downloads", "Workspace"]
var pillX = menuBarRect.maxX - 720
for (index, pill) in menuPills.enumerated() {
    let isActive = index == 0
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 23, weight: .semibold),
        .foregroundColor: isActive ? color(0.965, 0.961, 0.945) : NSColor.white.withAlphaComponent(0.78)
    ]
    let textSize = (pill as NSString).size(withAttributes: attributes)
    let rect = CGRect(x: pillX, y: menuBarRect.midY - 22, width: textSize.width + 38, height: 44)
    drawCapsule(rect, fill: isActive ? color(0.420, 0.561, 0.651) : NSColor.white.withAlphaComponent(0.13))
    (pill as NSString).draw(at: CGPoint(x: rect.minX + 19, y: rect.minY + 9), withAttributes: attributes)
    pillX = rect.maxX + 16
}

let iconRect = CGRect(x: 190, y: 875, width: 230, height: 230)
drawShadowed(
    rounded(iconRect.insetBy(dx: 2, dy: 2), 52),
    fill: NSColor.clear,
    shadowColor: NSColor.black.withAlphaComponent(0.18),
    blur: 24,
    offset: CGSize(width: 0, height: -10)
)
iconImage.draw(in: nsRect(iconRect),
               from: NSRect(origin: .zero, size: iconImage.size),
               operation: .sourceOver,
               fraction: 1.0)

let brandAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 84, weight: .heavy),
    .foregroundColor: color(0.169, 0.200, 0.227)
]
("Stashbar" as NSString).draw(at: CGPoint(x: 470, y: 1008), withAttributes: brandAttributes)

let headlineHeight = drawMultilineText(
    "메뉴바에 고정하는\n최근 파일 보관함",
    rect: CGRect(x: 190, y: 620, width: 930, height: 330),
    font: NSFont.systemFont(ofSize: 94, weight: .heavy),
    color: color(0.169, 0.200, 0.227),
    lineHeight: 0.94
)

let bodyTop = 620 - headlineHeight - 44
_ = drawMultilineText(
    "스크린샷, 다운로드, 작업 폴더를 한곳에 모아\nFinder를 열기 전 필요한 파일부터 확인합니다.",
    rect: CGRect(x: 196, y: bodyTop, width: 880, height: 160),
    font: NSFont.systemFont(ofSize: 37, weight: .medium),
    color: color(0.275, 0.325, 0.360),
    lineHeight: 1.08
)

let chips = ["최근 파일", "Quick Look", "다중 폴더", "로컬 전용"]
var chipX: CGFloat = 196
let chipY: CGFloat = 212
for (index, chip) in chips.enumerated() {
    let foreground = index == 0 ? color(0.965, 0.961, 0.945) : color(0.180, 0.240, 0.265)
    let fill = index == 0 ? color(0.420, 0.561, 0.651) : NSColor.white.withAlphaComponent(0.62)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: foreground
    ]
    let size = (chip as NSString).size(withAttributes: attributes)
    let rect = CGRect(x: chipX, y: chipY, width: size.width + 44, height: 58)
    drawCapsule(rect, fill: fill)
    (chip as NSString).draw(at: CGPoint(x: rect.minX + 22, y: rect.minY + 14), withAttributes: attributes)
    chipX = rect.maxX + 16
}

let stageRect = CGRect(x: 1160, y: 150, width: 1180, height: 930)
let stagePath = rounded(stageRect, 72)
drawShadowed(
    stagePath,
    fill: color(0.972, 0.968, 0.950, 0.96),
    shadowColor: NSColor.black.withAlphaComponent(0.20),
    blur: 42,
    offset: CGSize(width: 0, height: -24)
)

let previewFrame = stageRect.insetBy(dx: 74, dy: 88)
fillRounded(previewFrame, radius: 44, color: color(0.900, 0.920, 0.930))

let previewClip = rounded(previewFrame, 44)
NSGraphicsContext.current?.saveGraphicsState()
previewClip.addClip()
let previewDrawRect = aspectFitRect(for: previewImage.size, in: previewFrame)
previewImage.draw(in: nsRect(previewDrawRect),
                  from: NSRect(origin: .zero, size: previewImage.size),
                  operation: .sourceOver,
                  fraction: 1.0)
NSGraphicsContext.current?.restoreGraphicsState()

let calloutRect = CGRect(x: stageRect.minX + 74, y: stageRect.maxY - 74, width: 270, height: 48)
drawCapsule(calloutRect, fill: color(0.420, 0.561, 0.651))
let calloutAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 23, weight: .bold),
    .foregroundColor: color(0.965, 0.961, 0.945)
]
("LIVE MENU BAR" as NSString).draw(at: CGPoint(x: calloutRect.minX + 22, y: calloutRect.minY + 11), withAttributes: calloutAttributes)

let miniPanelRect = CGRect(x: 980, y: 700, width: 315, height: 190)
drawShadowed(
    rounded(miniPanelRect, 34),
    fill: color(0.169, 0.200, 0.227, 0.96),
    shadowColor: NSColor.black.withAlphaComponent(0.20),
    blur: 24,
    offset: CGSize(width: 0, height: -12)
)
let miniRows = [
    (color(0.420, 0.561, 0.651), 0.78),
    (color(0.690, 0.560, 0.380), 0.60),
    (color(0.330, 0.430, 0.520), 0.68)
]
for (index, row) in miniRows.enumerated() {
    let y = miniPanelRect.maxY - 55 - CGFloat(index) * 46
    drawCapsule(
        CGRect(x: miniPanelRect.minX + 32, y: y, width: miniPanelRect.width * row.1, height: 18),
        fill: row.0
    )
}

heroImage.unlockFocus()

let outputURL = URL(fileURLWithPath: outputPath)
do {
    try savePNG(heroImage, to: outputURL, pixelSize: heroSize)
} catch {
    fputs("error: failed to write hero image - \(error)\n", stderr)
    exit(1)
}
