#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon_dark.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let S: CGFloat = 1024
let center = CGPoint(x: S / 2, y: S / 2)
let corner = S * 0.2237

func R(_ r: CGRect) -> NSRect { NSRect(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height) }

let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bitmapFormat: .alphaFirst, bytesPerRow: 0, bitsPerPixel: 0)!
guard let gctx = NSGraphicsContext(bitmapImageRep: bmp) else { fatalError("no ctx") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

// mask
let mask = NSBezierPath(roundedRect: R(CGRect(x: 0, y: 0, width: S, height: S)), xRadius: corner, yRadius: corner)
mask.setClip()

// bg — deep dark
let bg = [
    NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.20, alpha: 1.0),
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.12, alpha: 1.0)
]
let bgL: [CGFloat] = [0.0, 1.0]
NSGradient(colors: bg, atLocations: bgL, colorSpace: .deviceRGB)?.draw(in: CGRect(x: 0, y: 0, width: S, height: S), angle: -45)

// ambient glow behind card
let glow = CGRect(x: center.x - S * 0.38, y: center.y - S * 0.38, width: S * 0.76, height: S * 0.76)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: S * 0.18, color: NSColor(calibratedRed: 0.30, green: 0.40, blue: 0.65, alpha: 0.10).cgColor)
let glowPath = NSBezierPath(ovalIn: R(glow))
NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.70, alpha: 0.05).setFill()
glowPath.fill()
ctx.restoreGState()

// === Main card ===
let cardW = S * 0.72
let cardH = S * 0.72
let cardR = S * 0.075
let cardRect = CGRect(x: center.x - cardW / 2, y: center.y - cardH / 2, width: cardW, height: cardH)
let cardPath = NSBezierPath(roundedRect: R(cardRect), xRadius: cardR, yRadius: cardR)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: S * 0.01), blur: S * 0.06, color: NSColor(calibratedWhite: 0.0, alpha: 0.25).cgColor)
NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.28, alpha: 1.0).setFill()
cardPath.fill()
ctx.restoreGState()

// subtle rim
ctx.saveGState()
cardPath.addClip()
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: S * 0.015, color: NSColor(white: 1.0, alpha: 0.08).cgColor)
NSColor(white: 1.0, alpha: 0.0).setStroke()
cardPath.lineWidth = 2
cardPath.stroke()
ctx.restoreGState()

// === Content ===
let pad = cardW * 0.085
let content = cardRect.insetBy(dx: pad, dy: pad)

// Top title pill
let titleH = content.height * 0.055
let titleW = content.width * 0.32
let titleRect = CGRect(x: content.midX - titleW / 2, y: content.maxY - titleH, width: titleW, height: titleH)
let titlePath = NSBezierPath(roundedRect: R(titleRect), xRadius: titleH / 2, yRadius: titleH / 2)
NSColor(calibratedWhite: 0.35, alpha: 1.0).setFill()
titlePath.fill()

// 4 rows
let rows = 4
let gap = content.height * 0.028
let rowH = (content.height - titleH - gap * CGFloat(rows + 1)) / CGFloat(rows)

for i in 0..<rows {
    let isSel = (i == 2)
    let rowY = content.minY + gap + CGFloat(rows - 1 - i) * (rowH + gap)
    let rowW = isSel ? content.width : content.width * 0.78
    let rowRect = CGRect(x: content.minX, y: rowY, width: rowW, height: rowH)
    let rowPath = NSBezierPath(roundedRect: R(rowRect), xRadius: rowH / 2, yRadius: rowH / 2)

    if isSel {
        NSColor(calibratedRed: 0.35, green: 0.60, blue: 1.0, alpha: 1.0).setFill()
    } else {
        NSColor(calibratedRed: 0.28, green: 0.30, blue: 0.35, alpha: 1.0).setFill()
    }
    rowPath.fill()

    if isSel {
        let d = rowH * 0.22
        let dot = CGRect(x: rowRect.minX + rowH * 0.32, y: rowRect.midY - d / 2, width: d, height: d)
        let dotPath = NSBezierPath(ovalIn: R(dot))
        NSColor.white.setFill()
        dotPath.fill()
    }
}

// sheen
let sheen = NSBezierPath(roundedRect: R(cardRect), xRadius: cardR, yRadius: cardR)
NSGradient(colors: [NSColor(white: 1.0, alpha: 0.05), NSColor(white: 1.0, alpha: 0.01), NSColor(white: 1.0, alpha: 0.0)],
             atLocations: [0.0, 0.25, 1.0], colorSpace: .deviceRGB)?.draw(in: sheen, angle: -48)

// outer rim
NSColor(white: 1.0, alpha: 0.10).setStroke()
NSBezierPath(roundedRect: R(CGRect(x: 0.5, y: 0.5, width: S - 1, height: S - 1)), xRadius: corner, yRadius: corner).stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bmp.representation(using: .png, properties: [:]) else { fatalError("png fail") }
try png.write(to: URL(fileURLWithPath: outputPath))
