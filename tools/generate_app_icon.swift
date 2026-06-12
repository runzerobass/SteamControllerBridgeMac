// Renders the app icon at all required sizes.
// Usage: swift tools/generate_app_icon.swift <output-directory>
//
// Design: white Steam-controller-style glyph (pill body, two round
// trackpads, Steam button) on a Steam-palette gradient squircle, drawn
// as vectors on a 1024-unit canvas so every size renders crisp.

import AppKit

func drawIcon(canvas: CGFloat) {
    let s = canvas / 1024.0

    // Background squircle on Apple's 824pt icon grid.
    let background = NSBezierPath(
        roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
        xRadius: 185 * s, yRadius: 185 * s)
    let gradient = NSGradient(
        starting: NSColor(red: 0.165, green: 0.278, blue: 0.369, alpha: 1), // steam blue
        ending: NSColor(red: 0.106, green: 0.157, blue: 0.220, alpha: 1))!  // steam dark
    gradient.draw(in: background, angle: -90)

    NSColor.white.setStroke()
    NSColor.white.setFill()

    // Controller body: stadium shape.
    let body = NSBezierPath(
        roundedRect: NSRect(x: 212 * s, y: 342 * s, width: 600 * s, height: 340 * s),
        xRadius: 170 * s, yRadius: 170 * s)
    body.lineWidth = 30 * s
    body.stroke()

    // The two signature trackpads — square on the 2026 controller.
    for centerX: CGFloat in [382, 642] {
        let half: CGFloat = 68
        let pad = NSBezierPath(
            roundedRect: NSRect(x: (centerX - half) * s, y: (548 - half) * s,
                                width: half * 2 * s, height: half * 2 * s),
            xRadius: 24 * s, yRadius: 24 * s)
        pad.lineWidth = 24 * s
        pad.stroke()
    }

    // Thumbsticks, lower-inner.
    for centerX: CGFloat in [462, 562] {
        let radius: CGFloat = 26
        NSBezierPath(ovalIn: NSRect(
            x: (centerX - radius) * s, y: (430 - radius) * s,
            width: radius * 2 * s, height: radius * 2 * s)).fill()
    }
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(canvas: CGFloat(pixels))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift generate_app_icon.swift <output-directory>")
    exit(1)
}
let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let url = outputDir.appendingPathComponent("icon_\(pixels).png")
    try renderPNG(pixels: pixels).write(to: url)
    print("wrote \(url.path)")
}
