#!/usr/bin/env swift

import AppKit

struct Palette {
    let top: NSColor
    let bottom: NSColor
    let accent: NSColor
    let accentSoft: NSColor
    let card: NSColor
}

struct Scene {
    let filename: String
    let screenshotFilename: String
    let badge: String
    let title: String
    let subtitle: String
    let detail: String
    let chips: [String]
    let focusRect: CGRect?
    let focusLabel: String?
    let palette: Palette
}

let canvasSize = NSSize(width: 2560, height: 1600)
let screenshotCardRect = CGRect(x: 1210, y: 290, width: 1200, height: 900)
let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppStore", isDirectory: true)
let screenshotDirectory = outputRoot
    .appendingPathComponent("screenshots/mac/ko-KR", isDirectory: true)
let liveScreenshotDirectory = outputRoot
    .appendingPathComponent("screenshots-live/mac/ko-KR", isDirectory: true)
let iconDirectory = outputRoot.appendingPathComponent("icons", isDirectory: true)

let resourcesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources", isDirectory: true)
let previewURL = resourcesURL.appendingPathComponent("preview.png")
let iconCandidates = [
    resourcesURL.appendingPathComponent("StashbarIcon.png"),
    resourcesURL.appendingPathComponent("FileStackIcon.png")
]

guard let previewImage = NSImage(contentsOf: previewURL) else {
    fputs("error: missing Resources/preview.png\n", stderr)
    exit(1)
}

guard let iconURL = iconCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
      let iconImage = NSImage(contentsOf: iconURL) else {
    fputs("error: missing Resources/StashbarIcon.png\n", stderr)
    exit(1)
}

let scenes: [Scene] = [
    Scene(
        filename: "01-menu-bar-recent-files.png",
        screenshotFilename: "01-live-icon-grid.png",
        badge: "MENU BAR",
        title: "메뉴바에서 최근 파일을 바로 확인",
        subtitle: "자주 보는 폴더를 Stashbar에 고정하고 최신 항목부터 확인합니다.",
        detail: "Finder 창을 먼저 열 필요 없이 메뉴바 팝오버에서 파일을 찾고 즉시 열 수 있습니다.",
        chips: ["최근 파일", "즉시 열기", "Stashbar"],
        focusRect: CGRect(x: 0.45, y: 0.27, width: 0.34, height: 0.24),
        focusLabel: "최근 항목 선택 영역",
        palette: Palette(
            top: NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.23, alpha: 1.0),
            bottom: NSColor(calibratedRed: 0.28, green: 0.38, blue: 0.45, alpha: 1.0),
            accent: NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.90, alpha: 1.0),
            accentSoft: NSColor(calibratedRed: 0.42, green: 0.56, blue: 0.65, alpha: 0.24),
            card: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
        )
    ),
    Scene(
        filename: "02-multi-folder-switching.png",
        screenshotFilename: "02-live-folder-switching.png",
        badge: "FOLDERS",
        title: "여러 폴더를 한곳에 고정",
        subtitle: "스크린샷, 다운로드, 작업 폴더를 드롭다운으로 전환합니다.",
        detail: "보안 북마크로 권한을 유지하고 폴더별 최신 파일 목록을 빠르게 다시 불러옵니다.",
        chips: ["다중 폴더", "보안 북마크", "빠른 전환"],
        focusRect: CGRect(x: 0.45, y: 0.10, width: 0.18, height: 0.08),
        focusLabel: "폴더 전환 드롭다운",
        palette: Palette(
            top: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 1.0),
            bottom: NSColor(calibratedRed: 0.35, green: 0.41, blue: 0.48, alpha: 1.0),
            accent: NSColor(calibratedRed: 0.88, green: 0.82, blue: 0.70, alpha: 1.0),
            accentSoft: NSColor(calibratedRed: 0.69, green: 0.56, blue: 0.38, alpha: 0.20),
            card: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
        )
    ),
    Scene(
        filename: "03-view-modes-and-sorting.png",
        screenshotFilename: "03-live-list-view.png",
        badge: "VIEWS",
        title: "보기 방식과 정렬을 빠르게 전환",
        subtitle: "아이콘, 목록, 계층 보기와 정렬 옵션을 짧은 동선 안에서 바꿉니다.",
        detail: "마우스로 탐색하든 키보드로 작업하든, 폴더 흐름을 끊지 않고 같은 자리에서 상태를 바꿀 수 있습니다.",
        chips: ["아이콘 보기", "목록 보기", "정렬 옵션"],
        focusRect: CGRect(x: 0.66, y: 0.10, width: 0.16, height: 0.08),
        focusLabel: "보기 모드 컨트롤",
        palette: Palette(
            top: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1.0),
            bottom: NSColor(calibratedRed: 0.25, green: 0.33, blue: 0.39, alpha: 1.0),
            accent: NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.90, alpha: 1.0),
            accentSoft: NSColor(calibratedRed: 0.42, green: 0.56, blue: 0.65, alpha: 0.20),
            card: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
        )
    ),
    Scene(
        filename: "04-keyboard-and-actions.png",
        screenshotFilename: "01-live-icon-grid.png",
        badge: "ACTIONS",
        title: "Quick Look과 Finder 단축키를 그대로",
        subtitle: "Space 미리보기, 복사·붙여넣기, 휴지통 이동까지 익숙한 맥 동작을 유지합니다.",
        detail: "메뉴바 도구처럼 가볍게 열어도 실제 파일 관리 작업까지 자연스럽게 이어지는 흐름에 맞췄습니다.",
        chips: ["Quick Look", "⌘C / ⌘V", "⌘⌫"],
        focusRect: nil,
        focusLabel: nil,
        palette: Palette(
            top: NSColor(calibratedRed: 0.23, green: 0.19, blue: 0.16, alpha: 1.0),
            bottom: NSColor(calibratedRed: 0.50, green: 0.43, blue: 0.35, alpha: 1.0),
            accent: NSColor(calibratedRed: 0.93, green: 0.88, blue: 0.80, alpha: 1.0),
            accentSoft: NSColor(calibratedRed: 0.69, green: 0.56, blue: 0.38, alpha: 0.20),
            card: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
        )
    ),
    Scene(
        filename: "05-cache-and-persistence.png",
        screenshotFilename: "04-live-hierarchy-view.png",
        badge: "LOCAL",
        title: "다시 열어도 빠르고 안전하게",
        subtitle: "디스크 캐시와 App Sandbox 호환 설계로 재실행 후에도 작업 흐름을 이어갑니다.",
        detail: "로그인 시 자동 실행과 영속 북마크를 활용해 자주 보는 폴더를 메뉴바에 안정적으로 고정할 수 있습니다.",
        chips: ["디스크 캐시", "로그인 시 실행", "Sandbox 준비 완료"],
        focusRect: nil,
        focusLabel: nil,
        palette: Palette(
            top: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0),
            bottom: NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.23, alpha: 1.0),
            accent: NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.90, alpha: 1.0),
            accentSoft: NSColor(calibratedRed: 0.42, green: 0.56, blue: 0.65, alpha: 0.20),
            card: NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
        )
    )
]

func nsRect(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
}

func createDirectoryIfNeeded(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
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
        throw NSError(domain: "AppStoreAssets", code: 1)
    }

    bitmap.size = pixelSize

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "AppStoreAssets", code: 2)
    }
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high
    image.draw(
        in: NSRect(origin: .zero, size: pixelSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppStoreAssets", code: 3)
    }
    try pngData.write(to: url)
}

func drawRoundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor) {
    let path = NSBezierPath(roundedRect: nsRect(rect), xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
}

func drawChip(text: String, origin: CGPoint, fill: NSColor, foreground: NSColor) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 24, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: foreground
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    let rect = CGRect(x: origin.x, y: origin.y, width: size.width + 42, height: 52)
    drawRoundedRect(rect, radius: rect.height / 2, fill: fill)
    (text as NSString).draw(
        at: CGPoint(x: rect.minX + 21, y: rect.minY + 12),
        withAttributes: attributes
    )
    return rect.width
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
    attributed.draw(with: nsRect(CGRect(x: rect.minX, y: rect.maxY - bounds.height, width: rect.width, height: bounds.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
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

func normalizedTopLeftRect(_ rect: CGRect, inside drawRect: CGRect) -> CGRect {
    CGRect(
        x: drawRect.minX + rect.minX * drawRect.width,
        y: drawRect.maxY - (rect.minY + rect.height) * drawRect.height,
        width: rect.width * drawRect.width,
        height: rect.height * drawRect.height
    )
}

func exportAppStoreIcon() throws {
    createDirectoryIfNeeded(iconDirectory)
    let exportSize = NSSize(width: 1024, height: 1024)
    let exportImage = NSImage(size: exportSize)
    exportImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    iconImage.draw(in: NSRect(origin: .zero, size: exportSize),
                   from: NSRect(origin: .zero, size: iconImage.size),
                   operation: .sourceOver,
                   fraction: 1.0)
    exportImage.unlockFocus()
    try savePNG(exportImage, to: iconDirectory.appendingPathComponent("stashbar-app-store-icon-1024.png"), pixelSize: exportSize)
    try savePNG(exportImage, to: iconDirectory.appendingPathComponent("file-stack-app-store-icon-1024.png"), pixelSize: exportSize)
}

func renderScene(_ scene: Scene) throws {
    let sceneScreenshotURL = liveScreenshotDirectory.appendingPathComponent(scene.screenshotFilename)
    let sceneScreenshotImage = NSImage(contentsOf: sceneScreenshotURL) ?? previewImage
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "AppStoreAssets", code: 2)
    }

    let canvasRect = CGRect(origin: .zero, size: canvasSize)

    if let gradient = NSGradient(colors: [scene.palette.top, scene.palette.bottom]) {
        gradient.draw(in: NSBezierPath(rect: nsRect(canvasRect)), angle: -30)
    }

    context.saveGState()
    for index in 0..<5 {
        let rect = CGRect(
            x: -240,
            y: 250 + CGFloat(index) * 235,
            width: 1720,
            height: 72
        )
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: -10 * .pi / 180)
        drawRoundedRect(
            CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height),
            radius: rect.height / 2,
            fill: index == 2 ? scene.palette.accentSoft : NSColor.white.withAlphaComponent(0.08)
        )
        context.restoreGState()
    }
    context.restoreGState()

    let smallIconRect = CGRect(x: 160, y: 1336, width: 86, height: 86)
    iconImage.draw(in: nsRect(smallIconRect),
                   from: NSRect(origin: .zero, size: iconImage.size),
                   operation: .sourceOver,
                   fraction: 1.0)

    let badgeRect = CGRect(x: 270, y: 1360, width: 260, height: 44)
    drawRoundedRect(badgeRect, radius: 22, fill: NSColor.white.withAlphaComponent(0.16))
    let badgeAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    (scene.badge as NSString).draw(at: CGPoint(x: badgeRect.minX + 20, y: badgeRect.minY + 10), withAttributes: badgeAttributes)

    let titleHeight = drawMultilineText(
        scene.title,
        rect: CGRect(x: 160, y: 980, width: 920, height: 300),
        font: NSFont.systemFont(ofSize: 110, weight: .heavy),
        color: .white,
        lineHeight: 0.95
    )

    let subtitleTop = 980 - titleHeight - 56
    let subtitleHeight = drawMultilineText(
        scene.subtitle,
        rect: CGRect(x: 168, y: subtitleTop, width: 860, height: 180),
        font: NSFont.systemFont(ofSize: 44, weight: .semibold),
        color: NSColor.white.withAlphaComponent(0.96),
        lineHeight: 1.05
    )

    var chipX: CGFloat = 168
    let chipY = subtitleTop - subtitleHeight - 74
    for chip in scene.chips {
        let width = drawChip(
            text: chip,
            origin: CGPoint(x: chipX, y: chipY),
            fill: NSColor.white.withAlphaComponent(0.14),
            foreground: NSColor.white
        )
        chipX += width + 18
    }

    let detailRect = CGRect(x: 168, y: 190, width: 860, height: 260)
    _ = drawMultilineText(
        scene.detail,
        rect: detailRect,
        font: NSFont.systemFont(ofSize: 31, weight: .regular),
        color: scene.palette.accent,
        lineHeight: 1.16
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -20)

    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    drawRoundedRect(screenshotCardRect, radius: 54, fill: scene.palette.card.withAlphaComponent(0.98))
    NSGraphicsContext.current?.restoreGraphicsState()

    let screenshotInnerRect = screenshotCardRect.insetBy(dx: 54, dy: 54)
    let screenshotDrawRect = aspectFitRect(for: sceneScreenshotImage.size, in: screenshotInnerRect)

    drawRoundedRect(screenshotInnerRect, radius: 36, fill: NSColor(calibratedWhite: 0.97, alpha: 1.0))
    NSGraphicsContext.current?.saveGraphicsState()
    let clipPath = NSBezierPath(roundedRect: nsRect(screenshotInnerRect), xRadius: 36, yRadius: 36)
    clipPath.addClip()
    sceneScreenshotImage.draw(in: nsRect(screenshotDrawRect),
                              from: NSRect(origin: .zero, size: sceneScreenshotImage.size),
                              operation: .sourceOver,
                              fraction: 1.0)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Re-establish focus after clipping restore.
    let screenshotLabelRect = CGRect(x: screenshotCardRect.minX + 56, y: screenshotCardRect.maxY - 86, width: 200, height: 44)
    drawRoundedRect(screenshotLabelRect, radius: 22, fill: scene.palette.accentSoft.withAlphaComponent(0.32))
    let screenshotLabelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: scene.palette.top
    ]
    ("LIVE UI" as NSString).draw(at: CGPoint(x: screenshotLabelRect.minX + 20, y: screenshotLabelRect.minY + 10), withAttributes: screenshotLabelAttributes)

    if let focusRect = scene.focusRect {
        let actualFocusRect = normalizedTopLeftRect(focusRect, inside: screenshotDrawRect)
        let insetFocusRect = actualFocusRect.insetBy(dx: -10, dy: -10)
        let focusPath = NSBezierPath(roundedRect: nsRect(insetFocusRect), xRadius: 34, yRadius: 34)
        scene.palette.accent.withAlphaComponent(0.20).setFill()
        focusPath.fill()
        scene.palette.accent.setStroke()
        focusPath.lineWidth = 8
        focusPath.stroke()

        if let focusLabel = scene.focusLabel {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: scene.palette.top
            ]
            let labelSize = (focusLabel as NSString).size(withAttributes: labelAttributes)
            let labelRect = CGRect(
                x: min(max(actualFocusRect.minX, screenshotCardRect.minX + 56), screenshotCardRect.maxX - labelSize.width - 70),
                y: min(actualFocusRect.maxY + 22, screenshotCardRect.maxY - 92),
                width: labelSize.width + 28,
                height: 42
            )
            drawRoundedRect(labelRect, radius: 21, fill: scene.palette.accent)
            (focusLabel as NSString).draw(at: CGPoint(x: labelRect.minX + 14, y: labelRect.minY + 10), withAttributes: labelAttributes)
        }
    }

    image.unlockFocus()

    try savePNG(image, to: screenshotDirectory.appendingPathComponent(scene.filename), pixelSize: canvasSize)
}

createDirectoryIfNeeded(screenshotDirectory)
createDirectoryIfNeeded(iconDirectory)

do {
    try exportAppStoreIcon()
    for scene in scenes {
        try renderScene(scene)
    }
} catch {
    fputs("error: failed to generate App Store assets - \(error)\n", stderr)
    exit(1)
}
