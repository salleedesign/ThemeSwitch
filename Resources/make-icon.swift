// Generates Resources/AppIcon.icns from Icon_Art_1024.png.
// Run: swift Resources/make-icon.swift && iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
//
// The master is Figma's own 1024 render rather than the source SVG: AppKit
// rasterises the art's gaussian blurs and inner shadow noticeably flatter than
// Figma does, losing the drop shadow under the circle.
//
// That export is full-bleed with opaque corners (it is the iOS shape, which the
// OS masks at render time). macOS wants the art inset and cut to the app-icon
// plate, so this masks it to a superellipse at the standard 824/1024 ratio.
import AppKit

_ = NSApplication.shared

let canvas: CGFloat = 1024
let inset: CGFloat = 100          // Apple's grid leaves the art ~824pt wide
let side = canvas - inset * 2

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let artURL = root.appendingPathComponent("Icon_Art_1024.png")
guard let art = NSImage(contentsOf: artURL) else {
    fatalError("could not load \(artURL.path)")
}

/// A superellipse rather than a rounded rect: NSBezierPath's rounded corners
/// are circular arcs, which read as visibly "wrong" next to macOS's continuous
/// curve.
func squircle(in rect: NSRect, exponent: CGFloat = 4.4, samples: Int = 720) -> NSBezierPath {
    let a = rect.width / 2, b = rect.height / 2
    let path = NSBezierPath()
    for i in 0...samples {
        let t = CGFloat(i) / CGFloat(samples) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * pow(abs(c), 2 / exponent) * (c < 0 ? -1 : 1)
        let y = rect.midY + b * pow(abs(s), 2 / exponent) * (s < 0 ? -1 : 1)
        i == 0 ? path.move(to: NSPoint(x: x, y: y)) : path.line(to: NSPoint(x: x, y: y))
    }
    path.close()
    return path
}

func drawIcon() {
    let plate = NSRect(x: inset, y: inset, width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.imageInterpolation = .high
    squircle(in: plate).addClip()
    art.draw(in: plate)
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.scaleBy(
        x: CGFloat(px) / canvas, y: CGFloat(px) / canvas)   // redrawn per size, never upscaled
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2),
                        (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = points * scale
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try! render(px).representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent(name))
}

// A standalone preview, handy for the README.
try! render(512).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("icon-preview.png"))
print("wrote \(iconset.path)")
