// Generates Resources/AppIcon.icns. Run: swift Resources/make-icon.swift
//
// The icon restates the menu bar glyph: a circle with its left half filled,
// sitting on a light-to-dark gradient. The split is vertical and the gradient
// runs the same way, so the dark half always sits on light ground and the light
// half on dark ground -- it keeps its contrast down at 16pt in a Finder list.
import AppKit

_ = NSApplication.shared

let canvas: CGFloat = 1024
let inset: CGFloat = 100          // Apple's grid leaves the art ~824pt wide
let side = canvas - inset * 2

// The plate stays inside one hue family. A cream-to-navy gradient interpolates
// through grey in RGB and turns to mud at the midpoint; pale-blue-to-navy never
// desaturates. Cream is held back for the circle so it stays the one warm accent.
let plateLight = NSColor(srgbRed: 0.851, green: 0.886, blue: 0.961, alpha: 1)  // #D9E2F5
let plateDark  = NSColor(srgbRed: 0.055, green: 0.075, blue: 0.180, alpha: 1)  // #0E132E
let discLight  = NSColor(srgbRed: 0.992, green: 0.949, blue: 0.863, alpha: 1)  // #FDF2DC
let discDark   = NSColor(srgbRed: 0.043, green: 0.059, blue: 0.141, alpha: 1)  // #0B0F24
let ring       = NSColor(white: 0.5, alpha: 0.28)

/// A superellipse rather than a rounded rect: NSBezierPath's rounded corners are
/// circular arcs, which read as visibly "wrong" next to macOS's continuous curve.
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
    let shape = squircle(in: plate)

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [plateLight, plateDark])!.draw(in: plate, angle: -12)
    NSGraphicsContext.restoreGraphicsState()

    let d = side * 0.52
    let circleRect = NSRect(x: plate.midX - d / 2, y: plate.midY - d / 2, width: d, height: d)
    let circle = NSBezierPath(ovalIn: circleRect)

    NSGraphicsContext.saveGraphicsState()
    circle.addClip()
    discDark.setFill()
    NSRect(x: circleRect.minX, y: circleRect.minY, width: d / 2, height: d).fill()
    discLight.setFill()
    NSRect(x: circleRect.midX, y: circleRect.minY, width: d / 2, height: d).fill()
    NSGraphicsContext.restoreGraphicsState()

    ring.setStroke()
    circle.lineWidth = side * 0.010
    circle.stroke()
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

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2),
                        (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = points * scale
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    let data = render(px).representation(using: .png, properties: [:])!
    try! data.write(to: iconset.appendingPathComponent(name))
}

// A standalone preview, handy for the README.
try! render(512).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("icon-preview.png"))
print("wrote \(iconset.path)")
