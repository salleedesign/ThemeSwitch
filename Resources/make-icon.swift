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

let canvas: CGFloat = 1024
let inset: CGFloat = 100          // Apple's grid leaves the art ~824pt wide
let plate = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let art = NSImage(contentsOf: root.appendingPathComponent("Icon_Art_1024.png"))!

/// A superellipse rather than a rounded rect: NSBezierPath's rounded corners
/// are circular arcs, which read as visibly "wrong" next to macOS's continuous
/// curve.
func squircle(in rect: NSRect) -> NSBezierPath {
    let exponent: CGFloat = 4.4, samples = 720
    func curve(_ v: CGFloat) -> CGFloat { copysign(pow(abs(v), 2 / exponent), v) }
    let path = NSBezierPath()
    for i in 0...samples {
        let t = CGFloat(i) / CGFloat(samples) * 2 * .pi
        let point = NSPoint(x: rect.midX + rect.width / 2 * curve(cos(t)),
                            y: rect.midY + rect.height / 2 * curve(sin(t)))
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    return path
}

/// PNG of the icon at `px` pixels, drawn from the master at that size rather
/// than downscaled from a larger render.
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: CGFloat(px) / canvas, y: CGFloat(px) / canvas)
    squircle(in: plate).addClip()
    art.draw(in: plate)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! render(points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

// A standalone preview, handy for the README.
try! render(512).write(to: root.appendingPathComponent("icon-preview.png"))
print("wrote \(iconset.path)")
