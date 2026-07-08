#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon_dark.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let S: CGFloat = 2048
let canvasRect = CGRect(x: 0, y: 0, width: S, height: S)

func R(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: R(rect), xRadius: radius, yRadius: radius)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    rounded(rect, radius).fill()
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

func drawTray(rect: CGRect, radius: CGFloat, notchWidth: CGFloat, notchDepth: CGFloat, fill: NSColor) {
    let midX = rect.midX
    let maxY = rect.maxY
    let minY = rect.minY
    let minX = rect.minX
    let maxX = rect.maxX
    let notchLeft = midX - notchWidth / 2
    let notchRight = midX + notchWidth / 2

    let path = NSBezierPath()
    path.move(to: NSPoint(x: minX + radius, y: minY))
    path.line(to: NSPoint(x: maxX - radius, y: minY))
    path.curve(to: NSPoint(x: maxX, y: minY + radius),
               controlPoint1: NSPoint(x: maxX - radius * 0.45, y: minY),
               controlPoint2: NSPoint(x: maxX, y: minY + radius * 0.45))
    path.line(to: NSPoint(x: maxX, y: maxY - radius))
    path.curve(to: NSPoint(x: maxX - radius, y: maxY),
               controlPoint1: NSPoint(x: maxX, y: maxY - radius * 0.45),
               controlPoint2: NSPoint(x: maxX - radius * 0.45, y: maxY))
    path.line(to: NSPoint(x: notchRight, y: maxY))
    path.curve(to: NSPoint(x: midX, y: maxY - notchDepth),
               controlPoint1: NSPoint(x: notchRight - notchWidth * 0.18, y: maxY),
               controlPoint2: NSPoint(x: midX + notchWidth * 0.28, y: maxY - notchDepth))
    path.curve(to: NSPoint(x: notchLeft, y: maxY),
               controlPoint1: NSPoint(x: midX - notchWidth * 0.28, y: maxY - notchDepth),
               controlPoint2: NSPoint(x: notchLeft + notchWidth * 0.18, y: maxY))
    path.line(to: NSPoint(x: minX + radius, y: maxY))
    path.curve(to: NSPoint(x: minX, y: maxY - radius),
               controlPoint1: NSPoint(x: minX + radius * 0.45, y: maxY),
               controlPoint2: NSPoint(x: minX, y: maxY - radius * 0.45))
    path.line(to: NSPoint(x: minX, y: minY + radius))
    path.curve(to: NSPoint(x: minX + radius, y: minY),
               controlPoint1: NSPoint(x: minX, y: minY + radius * 0.45),
               controlPoint2: NSPoint(x: minX + radius * 0.45, y: minY))
    path.close()

    drawShadowed(
        path,
        fill: fill,
        shadowColor: NSColor.black.withAlphaComponent(0.24),
        blur: S * 0.028,
        offset: CGSize(width: 0, height: -S * 0.010)
    )
}

let backgroundTop = color(0.094, 0.113, 0.129)
let backgroundBottom = color(0.055, 0.067, 0.078)
let tray = color(0.880, 0.890, 0.880)
let steel = color(0.420, 0.561, 0.651) // #6B8FA6
let steelLight = color(0.600, 0.702, 0.765)

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(S),
    pixelsHigh: Int(S),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("no graphics context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
graphicsContext.imageInterpolation = .high
let context = graphicsContext.cgContext

NSGradient(colors: [backgroundTop, backgroundBottom], atLocations: [0, 1], colorSpace: .deviceRGB)?
    .draw(in: canvasRect, angle: -45)

context.saveGState()
context.setAlpha(0.16)
fillRounded(
    CGRect(x: -S * 0.08, y: S * 0.23, width: S * 1.16, height: S * 0.055),
    radius: S * 0.028,
    fill: steel
)
context.restoreGState()

let fileRect = CGRect(x: S * 0.340, y: S * 0.370, width: S * 0.320, height: S * 0.440)
drawShadowed(
    rounded(fileRect, S * 0.030),
    fill: steel,
    shadowColor: NSColor.black.withAlphaComponent(0.16),
    blur: S * 0.018,
    offset: CGSize(width: 0, height: -S * 0.006)
)

let fold = S * 0.116
let foldCut = NSBezierPath()
foldCut.move(to: NSPoint(x: fileRect.maxX - fold, y: fileRect.maxY))
foldCut.line(to: NSPoint(x: fileRect.maxX, y: fileRect.maxY))
foldCut.line(to: NSPoint(x: fileRect.maxX, y: fileRect.maxY - fold))
foldCut.close()
backgroundTop.setFill()
foldCut.fill()

let foldFace = NSBezierPath()
foldFace.move(to: NSPoint(x: fileRect.maxX - fold * 0.86, y: fileRect.maxY - S * 0.006))
foldFace.line(to: NSPoint(x: fileRect.maxX - S * 0.006, y: fileRect.maxY - fold * 0.86))
foldFace.line(to: NSPoint(x: fileRect.maxX - fold * 0.86, y: fileRect.maxY - fold * 0.86))
foldFace.close()
steelLight.setFill()
foldFace.fill()

let trayRect = CGRect(x: S * 0.210, y: S * 0.285, width: S * 0.580, height: S * 0.235)
drawTray(
    rect: trayRect,
    radius: S * 0.064,
    notchWidth: S * 0.206,
    notchDepth: S * 0.064,
    fill: tray
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("png fail")
}
try png.write(to: URL(fileURLWithPath: outputPath))
