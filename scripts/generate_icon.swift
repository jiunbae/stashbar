#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let S: CGFloat = 1024
let center = CGPoint(x: S / 2, y: S / 2)
let corner = S * 0.2237

func R(_ r: CGRect) -> NSRect { NSRect(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height) }

let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

// mask
let mask = NSBezierPath(roundedRect: R(CGRect(x: 0, y: 0, width: S, height: S)), xRadius: corner, yRadius: corner)
mask.setClip()

// bg — very subtle cool white
let bg = [
    NSColor(calibratedRed: 0.96, green: 0.965, blue: 0.98, alpha: 1.0),
    NSColor(calibratedRed: 0.90, green: 0.905, blue: 0.95, alpha: 1.0)
]
let bgL: [CGFloat] = [0.0, 1.0]
NSGradient(colors: bg, atLocations: bgL, colorSpace: .deviceRGB)?.draw(in: CGRect(x: 0, y: 0, width: S, height: S), angle: -45)

// === Main card — much larger, filling the canvas ===
let cardW = S * 0.72
let cardH = S * 0.72
let cardR = S * 0.075
let cardRect = CGRect(x: center.x - cardW / 2, y: center.y - cardH / 2, width: cardW, height: cardH)
let cardPath = NSBezierPath(roundedRect: R(cardRect), xRadius: cardR, yRadius: cardR)

// strong but soft shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: S * 0.01), blur: S * 0.06, color: NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.60, alpha: 0.18).cgColor)
NSColor.white.setFill()
cardPath.fill()
ctx.restoreGState()

// subtle top-edge gloss
ctx.saveGState()
cardPath.addClip()
ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: NSColor(white: 1.0, alpha: 0.45).cgColor)
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
NSColor(calibratedWhite: 0.90, alpha: 1.0).setFill()
titlePath.fill()

// 4 rows, chunky
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
        NSColor(calibratedRed: 0.20, green: 0.50, blue: 1.0, alpha: 1.0).setFill()
    } else {
        NSColor(calibratedWhite: 0.935, alpha: 1.0).setFill()
    }
    rowPath.fill()

    // white dot on selected
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
NSGradient(colors: [NSColor(white: 1.0, alpha: 0.10), NSColor(white: 1.0, alpha: 0.02), NSColor(white: 1.0, alpha: 0.0)],
             atLocations: [0.0, 0.25, 1.0], colorSpace: .deviceRGB)?.draw(in: sheen, angle: -48)

// outer rim
NSColor(white: 1.0, alpha: 0.30).setStroke()
NSBezierPath(roundedRect: R(CGRect(x: 0.5, y: 0.5, width: S - 1, height: S - 1)), xRadius: corner, yRadius: corner).stroke()

img.unlockFocus()

guard let tiff = img.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff), let png = bmp.representation(using: .png, properties: [:]) else { fatalError("png fail") }
try png.write(to: URL(fileURLWithPath: outputPath))
