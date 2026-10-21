#!/usr/bin/env swift

import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en", "ja"]
/// The devices named on the command line (`./compose.swift Mac`), or all of them.
let requestedDevices = Set(CommandLine.arguments.dropFirst())

/// Captures live in `Raw/<device>/<lang>/` and are written to `<device>/<lang>/`.
enum Device: String {
    case iPhone
    case iPad
    case mac = "Mac"

    /// 6.5" iPhone, 13" iPad, and the Mac's 16:10.
    var canvasSize: NSSize {
        switch self {
        case .iPhone: NSSize(width: 1242, height: 2688)
        case .iPad: NSSize(width: 2064, height: 2752)
        case .mac: NSSize(width: 2880, height: 1800)
        }
    }

    var isRequested: Bool { requestedDevices.isEmpty || requestedDevices.contains(rawValue) }

    /// Text and margins are laid out for the iPhone canvas and scaled up by width.
    var scale: CGFloat { canvasSize.width / Device.iPhone.canvasSize.width }

    func rawDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent("Raw").appendingPathComponent(rawValue)
            .appendingPathComponent(language)
    }

    func outDir(_ language: String) -> URL {
        scriptDir.appendingPathComponent(rawValue).appendingPathComponent(language)
    }
}

struct Copy {
    let header: String
    let caption: String
}

struct Screenshot {
    let name: String
    /// Keyed by language code. A language without copy is skipped.
    let copy: [String: Copy]
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Send's sky blue from the app icon, deepening toward the bottom.
let accent = color(0x4DA1EB)
let gradientTop = accent
let gradientBottom = accent.blended(withFraction: 0.3, of: .black)!

let devicesCopy = [
    "en": Copy(header: "Send to Devices Nearby", caption: "Phones, tablets, and computers on your Wi-Fi"),
    "ja": Copy(header: "近くのデバイスにすぐ送れる", caption: "同じWi-Fiのスマホ・タブレット・パソコンへ"),
]
let offerCopy = [
    "en": Copy(header: "You Decide What Comes In", caption: "Nothing arrives until you accept it"),
    "ja": Copy(header: "受け取るかは自分で決める", caption: "受け入れるまでファイルは届きません"),
]
let transferCopy = [
    "en": Copy(header: "Fast, Even for Huge Files", caption: "Straight from one device to the other"),
    "ja": Copy(header: "大きなファイルも高速に", caption: "デバイスからデバイスへ直接転送"),
]
let pairCopy = [
    "en": Copy(header: "Pair Once with a QR Code", caption: "Every transfer after that is verified"),
    "ja": Copy(header: "QRコードで一度ペアリング", caption: "以降の転送はすべて自動で確認"),
]
let darkCopy = [
    "en": Copy(header: "Android, iPhone, Mac, and Windows", caption: "One way to share across all of them"),
    "ja": Copy(header: "Android・iPhone・Mac・Windows", caption: "どのデバイスとも同じ方法で共有"),
]
let settingsCopy = [
    "en": Copy(header: "No Accounts. No Cloud Storage.", caption: "You choose who can see your device"),
    "ja": Copy(header: "アカウントもクラウドも不要", caption: "このデバイスを見られる相手は自分で選べる"),
]

let iPhoneScreenshots = [
    Screenshot(name: "01-devices", copy: devicesCopy),
    Screenshot(name: "02-offer", copy: offerCopy),
    Screenshot(name: "03-transfer", copy: transferCopy),
    Screenshot(name: "04-pair", copy: pairCopy),
    Screenshot(name: "05-dark", copy: darkCopy),
    Screenshot(name: "06-settings", copy: settingsCopy),
]

let iPadScreenshots = iPhoneScreenshots

/// Settings on the Mac is its own window behind ⌘, so it is left out.
let macScreenshots = [
    Screenshot(name: "01-devices", copy: devicesCopy),
    Screenshot(name: "02-offer", copy: offerCopy),
    Screenshot(name: "03-transfer", copy: transferCopy),
    Screenshot(name: "04-pair", copy: pairCopy),
]

// MARK: - Text

/// SF Pro Rounded. It has no Japanese, so that falls back to Tsukushi A Round
/// Gothic, which unlike Hiragino Maru Gothic comes in a bold to match the header.
func roundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let system = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
    let japanese = weight >= .semibold ? "TsukuARdGothic-Bold" : "TsukuARdGothic-Regular"
    let rounded = (system.withDesign(.rounded) ?? system).addingAttributes([
        .cascadeList: [NSFontDescriptor(name: japanese, size: size)],
    ])
    return NSFont(descriptor: rounded, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

/// One line of text at the largest size up to `size` that fits `maxWidth`.
struct Line {
    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let font: NSFont
    let size: NSSize

    init(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxWidth: CGFloat) {
        var fontSize = size
        var font = roundedFont(ofSize: fontSize, weight: weight)
        var attributes: [NSAttributedString.Key: Any] = [:]
        var lineSize = NSSize.zero
        while fontSize > 10 {
            font = roundedFont(ofSize: fontSize, weight: weight)
            attributes = [.font: font, .foregroundColor: color]
            lineSize = (text as NSString).size(withAttributes: attributes)
            if lineSize.width <= maxWidth { break }
            fontSize -= 2
        }
        self.text = text
        self.attributes = attributes
        self.font = font
        self.size = lineSize
        (inkTop, inkBottom) = Line.inkInsets(of: text, attributes: attributes, size: lineSize)
    }

    /// How far below the top of the line box the glyphs actually start and end.
    let inkTop: CGFloat
    let inkBottom: CGFloat

    /// Centering by font metrics leaves the text looking off, since the line box carries
    /// space above the capitals and below the baseline. So the line is rendered once and
    /// the rows its glyphs cover are measured.
    private static func inkInsets(
        of text: String, attributes: [NSAttributedString.Key: Any], size: NSSize
    ) -> (CGFloat, CGFloat) {
        let width = Int(size.width.rounded(.up))
        let height = Int(size.height.rounded(.up))
        guard width > 0, height > 0, let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return (0, size.height) }
        bitmap.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        var opaque = attributes
        opaque[.foregroundColor] = NSColor.black
        (text as NSString).draw(at: .zero, withAttributes: opaque)
        NSGraphicsContext.restoreGraphicsState()

        // Bitmap rows run top to bottom.
        let inked = (0..<height).filter { y in
            (0..<width).contains { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 }
        }
        guard let first = inked.first, let last = inked.last else { return (0, size.height) }
        return (CGFloat(first), CGFloat(last + 1))
    }

    /// Draws the line centered across `canvasWidth`, with the top of its line box at `top`.
    func draw(top: CGFloat, canvasWidth: CGFloat) {
        (text as NSString).draw(
            at: NSPoint(x: (canvasWidth - size.width) / 2, y: top - size.height),
            withAttributes: attributes
        )
    }
}

// MARK: - Device frames

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

/// Draws `raw` aspect-filled into `rect`.
func drawFilled(_ raw: CGImage, in rect: CGRect, context: CGContext) {
    let rawSize = CGSize(width: raw.width, height: raw.height)
    let scale = max(rect.width / rawSize.width, rect.height / rawSize.height)
    let drawSize = CGSize(width: rawSize.width * scale, height: rawSize.height * scale)
    context.draw(raw, in: CGRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    ))
}

let hardwareImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Hardware@2x.png"))!
let displayImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Display@2x.png"))!
let hardwareCG = cgImage(of: hardwareImage)
let displayCG = cgImage(of: displayImage)
let hardwarePixel = NSSize(width: hardwareCG.width, height: hardwareCG.height)
let displayPixel = NSSize(width: displayCG.width, height: displayCG.height)
// The display mask sits centered within the hardware frame.
let displayOrigin = NSPoint(
    x: (hardwarePixel.width - displayPixel.width) / 2,
    y: (hardwarePixel.height - displayPixel.height) / 2
)

/// The raw capture clipped by the display mask, on a hardware-sized canvas.
func maskedScreen(raw: NSImage) -> NSImage {
    let image = NSImage(size: hardwarePixel)
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let displayRect = CGRect(origin: displayOrigin, size: displayPixel)
    ctx.clip(to: displayRect, mask: displayCG)
    drawFilled(cgImage(of: raw), in: displayRect, context: ctx)
    image.unlockFocus()
    return image
}

/// The iPad bezel, as a fraction of the device's width.
let iPadBezel: CGFloat = 0.03
let iPadCornerRadius: CGFloat = 0.05
/// 13" iPad Pro screen, width over height.
let iPadScreenAspect: CGFloat = 2064 / 2752

func deviceAspect(_ device: Device) -> CGFloat {
    switch device {
    case .iPhone:
        return hardwarePixel.width / hardwarePixel.height
    case .iPad, .mac:
        let screenHeight = (1 - 2 * iPadBezel) / iPadScreenAspect
        return 1 / (screenHeight + 2 * iPadBezel)
    }
}

/// A plain iPad Pro in black, drawn rather than imaged, with the capture on its screen.
func drawiPad(raw: NSImage, in rect: NSRect) {
    let ctx = NSGraphicsContext.current!.cgContext
    let bezel = rect.width * iPadBezel
    let outerRadius = rect.width * iPadCornerRadius

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    color(0x1C1C1E).setFill()
    NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // A lighter edge, as the aluminium band catches the light.
    let rim = NSBezierPath(
        roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: outerRadius - 2, yRadius: outerRadius - 2
    )
    rim.lineWidth = 4
    color(0x5A5A5E).setStroke()
    rim.stroke()

    let screenRect = rect.insetBy(dx: bezel, dy: bezel)
    let screenRadius = max(outerRadius - bezel * 0.8, 0)
    ctx.saveGState()
    NSBezierPath(roundedRect: screenRect, xRadius: screenRadius, yRadius: screenRadius).addClip()
    drawFilled(cgImage(of: raw), in: screenRect, context: ctx)
    ctx.restoreGState()
}

// MARK: - Mac windows

/// A window capture, with the shadow macOS gives a window in front.
func drawWindow(_ raw: NSImage, in rect: NSRect) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowBlurRadius = 70
    shadow.shadowOffset = NSSize(width: 0, height: -30)
    shadow.set()
    raw.draw(in: rect)
    NSGraphicsContext.current?.restoreGraphicsState()
}

/// A sheet is its own window, captured apart from the one it is attached to.
struct Sheet {
    let image: NSImage
    /// From the window's top-left corner to the sheet's, in points.
    let offset: NSPoint
    /// The window's width in points, which turns the offset into pixels.
    let windowWidth: CGFloat
}

/// Send's window is small and tall, so the text sits to its left rather than above.
func drawMac(copy: Copy, raw: NSImage, sheet: Sheet?, canvasSize: NSSize) {
    let margin: CGFloat = 160
    let windowHeight = canvasSize.height - 2 * margin
    let scale = windowHeight / raw.size.height
    let windowSize = NSSize(width: raw.size.width * scale, height: windowHeight)
    let windowRect = NSRect(
        x: canvasSize.width - margin * 1.6 - windowSize.width, y: margin,
        width: windowSize.width, height: windowSize.height
    )

    let textWidth = windowRect.minX - margin * 1.6 - margin
    let header = Line(copy.header, size: 120, weight: .bold, color: .white, maxWidth: textWidth)
    let caption = Line(
        copy.caption, size: 60, weight: .medium, color: NSColor.white.withAlphaComponent(0.92), maxWidth: textWidth
    )
    let captionGap: CGFloat = 12
    let inkHeight = header.size.height + captionGap + caption.inkBottom - header.inkTop
    let headerTop = ((canvasSize.height + inkHeight) / 2 + header.inkTop).rounded()
    let textCenter = margin * 1.6 + textWidth / 2
    // `Line` centres across a width, so it is drawn into a band around the text column.
    for (line, top) in [(header, headerTop), (caption, headerTop - header.size.height - captionGap)] {
        (line.text as NSString).draw(
            at: NSPoint(x: textCenter - line.size.width / 2, y: top - line.size.height),
            withAttributes: line.attributes
        )
    }

    drawWindow(raw, in: windowRect)
    if let sheet {
        let perPoint = windowRect.width / sheet.windowWidth
        let size = NSSize(
            width: sheet.image.size.width * scale, height: sheet.image.size.height * scale
        )
        // Points run down from the window's top; AppKit's origin is bottom-left.
        let origin = NSPoint(
            x: windowRect.minX + sheet.offset.x * perPoint,
            y: windowRect.maxY - sheet.offset.y * perPoint - size.height
        )
        drawWindow(sheet.image, in: NSRect(origin: origin, size: size))
    }
}

// MARK: - Composition

func compose(_ shot: Screenshot, language: String, device: Device) -> Bool {
    guard let copy = shot.copy[language] else { return true }
    let rawURL = device.rawDir(language).appendingPathComponent("\(shot.name).png")
    guard let raw = NSImage(contentsOf: rawURL) else {
        print("missing raw capture: \(rawURL.path)")
        return false
    }

    let canvasSize = device.canvasSize
    let s = device.scale
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSGradient(starting: gradientTop, ending: gradientBottom)?
        .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    if device == .mac {
        let dir = device.rawDir(language)
        var sheet: Sheet?
        if let image = NSImage(contentsOf: dir.appendingPathComponent("\(shot.name)-sheet.png")),
           let offset = try? String(contentsOf: dir.appendingPathComponent("\(shot.name)-sheet.txt"), encoding: .utf8)
               .split(separator: " ").compactMap({ Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
           offset.count == 3 {
            sheet = Sheet(image: image, offset: NSPoint(x: offset[0], y: offset[1]), windowWidth: offset[2])
        }
        drawMac(copy: copy, raw: raw, sheet: sheet, canvasSize: canvasSize)
        image.unlockFocus()
        return write(image, canvasSize: canvasSize, shot: shot, language: language, device: device)
    }

    // One-line header and caption. AppKit's origin is bottom-left.
    let textWidth = canvasSize.width - 96 * s
    let header = Line(copy.header, size: 84 * s, weight: .bold, color: .white, maxWidth: textWidth)
    let caption = Line(
        copy.caption, size: 44 * s, weight: .medium,
        color: NSColor.white.withAlphaComponent(0.92), maxWidth: textWidth
    )
    let captionGap = 4 * s
    // From the top of the header's ink to the bottom of the caption's.
    let inkHeight = header.size.height + captionGap + caption.inkBottom - header.inkTop

    let aspect = deviceAspect(device)
    var deviceSize: NSSize
    let deviceBottom: CGFloat
    let deviceTop: CGFloat
    switch device {
    case .iPhone:
        // The device fills what is left below a band that holds the text.
        let textPadding = 88 * s
        let deviceBottomMargin = 88 * s
        deviceTop = canvasSize.height - inkHeight - 2 * textPadding
        let availableHeight = deviceTop - deviceBottomMargin
        deviceSize = NSSize(width: availableHeight * aspect, height: availableHeight)
        if deviceSize.width > canvasSize.width - 120 * s {
            deviceSize.width = canvasSize.width - 120 * s
            deviceSize.height = deviceSize.width / aspect
        }
        deviceBottom = deviceTop - deviceSize.height
    case .iPad, .mac:
        // The iPad is drawn as wide as the margins allow and runs off the bottom of the
        // canvas, leaving a band above it for the text.
        deviceSize = NSSize(width: canvasSize.width - 140 * s, height: (canvasSize.width - 140 * s) / aspect)
        deviceTop = canvasSize.height - 300 * s
        deviceBottom = deviceTop - deviceSize.height
    }

    // The text's ink is centered in the band between the top of the canvas and the device.
    let inkTop = (canvasSize.height + deviceTop + inkHeight) / 2
    let headerTop = (inkTop + header.inkTop).rounded()
    header.draw(top: headerTop, canvasWidth: canvasSize.width)
    caption.draw(top: headerTop - header.size.height - captionGap, canvasWidth: canvasSize.width)

    let deviceRect = NSRect(
        x: ((canvasSize.width - deviceSize.width) / 2).rounded(),
        y: deviceBottom.rounded(),
        width: deviceSize.width,
        height: deviceSize.height
    )

    switch device {
    case .iPhone:
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 60
        shadow.shadowOffset = NSSize(width: 0, height: -24)
        shadow.set()
        hardwareImage.draw(in: deviceRect)
        NSGraphicsContext.current?.restoreGraphicsState()
        maskedScreen(raw: raw).draw(in: deviceRect)
    case .iPad, .mac:
        drawiPad(raw: raw, in: deviceRect)
    }

    image.unlockFocus()
    return write(image, canvasSize: canvasSize, shot: shot, language: language, device: device)
}

/// Rasterizes at exactly the canvas size in pixels and writes it out.
func write(_ image: NSImage, canvasSize: NSSize, shot: Screenshot, language: String, device: Device) -> Bool {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return false }
    bitmap.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { return false }
    let outDir = device.outDir(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("\(shot.name).png")
    do {
        try png.write(to: outURL)
        print("wrote \(outURL.path.replacingOccurrences(of: scriptDir.path + "/", with: ""))")
        return true
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return false
    }
}

var allOK = true
let sets: [(Device, [Screenshot])] = [(.iPhone, iPhoneScreenshots), (.iPad, iPadScreenshots), (.mac, macScreenshots)]
for language in languages {
    for (device, shots) in sets where device.isRequested {
        for shot in shots {
            allOK = compose(shot, language: language, device: device) && allOK
        }
    }
}
exit(allOK ? 0 : 1)
