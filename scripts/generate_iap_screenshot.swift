#!/usr/bin/env swift

// Renders an App Store review screenshot for the tip in-app purchases: a clean
// depiction of the Settings "Support Development" section with the three tips.
import AppKit

// Draw in a 1600x1000 logical space, rendered onto a 2560x1600 pixel canvas
// (a standard Mac App Store screenshot size that passes IAP asset validation).
let pixelSize = NSSize(width: 2560, height: 1600)
let size = NSSize(width: 1600, height: 1000)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconURL = ["Resources/StashbarIcon.png", "Resources/FileStackIcon.png"]
    .map { root.appendingPathComponent($0) }
    .first { FileManager.default.fileExists(atPath: $0.path) }
let icon = iconURL.flatMap { NSImage(contentsOf: $0) }

func rr(_ r: CGRect, _ rad: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad) }
func fill(_ r: CGRect, _ rad: CGFloat, _ c: NSColor) { c.setFill(); rr(r, rad).fill() }
func text(_ s: String, _ p: CGPoint, _ f: NSFont, _ c: NSColor) {
    (s as NSString).draw(at: p, withAttributes: [.font: f, .foregroundColor: c])
}
func textRight(_ s: String, maxX: CGFloat, y: CGFloat, _ f: NSFont, _ c: NSColor) {
    let w = (s as NSString).size(withAttributes: [.font: f]).width
    text(s, CGPoint(x: maxX - w, y: y), f, c)
}

let primary = NSColor(calibratedWhite: 0.13, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.46, alpha: 1)
let accent = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)

let img = NSImage(size: size)
img.lockFocus()

// window backdrop
NSGradient(colors: [NSColor(white: 0.95, alpha: 1), NSColor(white: 0.90, alpha: 1)])?
    .draw(in: NSRect(origin: .zero, size: size), angle: -90)

// settings card
let card = CGRect(x: 260, y: 120, width: 1080, height: 760)
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 40; shadow.shadowOffset = NSSize(width: 0, height: -14)
NSGraphicsContext.current?.saveGraphicsState(); shadow.set()
fill(card, 28, NSColor(white: 0.99, alpha: 1))
NSGraphicsContext.current?.restoreGraphicsState()

// header: icon + Stashbar Settings
if let icon { icon.draw(in: CGRect(x: card.minX + 48, y: card.maxY - 132, width: 84, height: 84)) }
text("Stashbar", CGPoint(x: card.minX + 152, y: card.maxY - 108), .systemFont(ofSize: 40, weight: .heavy), primary)
text("설정 · Settings", CGPoint(x: card.minX + 152, y: card.maxY - 148), .systemFont(ofSize: 22, weight: .regular), secondary)

// section title
let secY = card.maxY - 232
text("개발 지원 · Support Development", CGPoint(x: card.minX + 48, y: secY), .systemFont(ofSize: 26, weight: .bold), primary)
text("Stashbar가 마음에 드셨다면 개발을 응원해 주세요. 기능 잠금 없이 순수 후원입니다.",
     CGPoint(x: card.minX + 48, y: secY - 40), .systemFont(ofSize: 19, weight: .regular), secondary)

// tip rows
struct Tip { let name: String; let desc: String; let price: String }
let tips = [
    Tip(name: "Espresso", desc: "A small tip to support development. Thanks!", price: "$0.99"),
    Tip(name: "Latte", desc: "A generous tip to support development.", price: "$2.99"),
    Tip(name: "Dessert", desc: "A big thank-you tip for development.", price: "$4.99"),
]
var rowY = secY - 120
for tip in tips {
    let row = CGRect(x: card.minX + 48, y: rowY - 96, width: card.width - 96, height: 92)
    fill(row, 16, NSColor(white: 0.965, alpha: 1))
    text(tip.name, CGPoint(x: row.minX + 28, y: row.midY + 6), .systemFont(ofSize: 24, weight: .semibold), primary)
    text(tip.desc, CGPoint(x: row.minX + 28, y: row.midY - 30), .systemFont(ofSize: 18, weight: .regular), secondary)
    // price button
    let btnW: CGFloat = 132
    let btn = CGRect(x: row.maxX - btnW - 24, y: row.midY - 26, width: btnW, height: 52)
    fill(btn, 12, accent)
    let f = NSFont.systemFont(ofSize: 22, weight: .semibold)
    let tw = (tip.price as NSString).size(withAttributes: [.font: f]).width
    text(tip.price, CGPoint(x: btn.midX - tw / 2, y: btn.midY - 15), f, .white)
    rowY -= 116
}

img.unlockFocus()

// Render the logical image into an exact 2560x1600 pixel bitmap (avoids the
// Retina 2x backing that would otherwise produce an oversized 5120x3200 file).
guard let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixelSize.width),
        pixelsHigh: Int(pixelSize.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0) else {
    fputs("error: bitmap alloc failed\n", stderr); exit(1)
}
bmp.size = pixelSize
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
NSGraphicsContext.current?.imageInterpolation = .high
img.draw(in: NSRect(origin: .zero, size: pixelSize), from: NSRect(origin: .zero, size: img.size), operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()
guard let png = bmp.representation(using: .png, properties: [:]) else {
    fputs("error: png encode failed\n", stderr); exit(1)
}
let outDir = root.appendingPathComponent("AppStore/iap", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let out = outDir.appendingPathComponent("iap-review.png")
try! png.write(to: out)
print("wrote \(out.path)")
