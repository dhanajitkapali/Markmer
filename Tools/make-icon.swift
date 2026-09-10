#!/usr/bin/env swift
// Renders the Markmer app icon (an "M" drawn as a flowchart: circle → box → diamond → box → circle)
// at every size the macOS AppIcon set needs. Pure CoreGraphics, no external tools.
//
// Usage: swift Tools/make-icon.swift Markmer/Assets.xcassets/AppIcon.appiconset [extra-preview.png]

import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("usage: make-icon.swift <appiconset dir> [preview.png]\n", stderr)
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Continuous-corner ("squircle") path approximating Apple's icon shape.
func squircle(in rect: CGRect) -> CGPath {
    let r = rect.width * 0.2237
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func draw(size s: CGFloat, in ctx: CGContext) {
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Apple grid: 824pt tile on a 1024pt canvas.
    let inset = s * (100.0 / 1024.0)
    let tile = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let u = tile.width // unit for all proportions
    let path = squircle(in: tile)

    // Drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.018), blur: u * 0.045, color: color(0x000000, 0.35))
    ctx.setFillColor(color(0x2b2470))
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    // Gradient background: indigo → violet → teal.
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let bg = CGGradient(colorsSpace: space,
                        colors: [color(0x3b2fd6), color(0x6d5df6), color(0x1fb8a6)] as CFArray,
                        locations: [0, 0.48, 1])!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: tile.minX, y: tile.maxY),
                           end: CGPoint(x: tile.maxX, y: tile.minY),
                           options: [])

    // Soft top highlight.
    let hi = CGGradient(colorsSpace: space,
                        colors: [color(0xffffff, 0.22), color(0xffffff, 0.0)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(hi,
                           start: CGPoint(x: tile.midX, y: tile.maxY),
                           end: CGPoint(x: tile.midX, y: tile.midY),
                           options: [])

    // Faint grid dots, a nod to a canvas.
    ctx.setFillColor(color(0xffffff, 0.07))
    let step = u / 12
    var gy = tile.minY + step
    while gy < tile.maxY {
        var gx = tile.minX + step
        while gx < tile.maxX {
            ctx.fillEllipse(in: CGRect(x: gx - u * 0.006, y: gy - u * 0.006, width: u * 0.012, height: u * 0.012))
            gx += step
        }
        gy += step
    }
    ctx.restoreGState()

    // The "M" as a flowchart. Points in tile-relative coordinates (y up).
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: tile.minX + x * u, y: tile.minY + y * u) }
    let a = p(0.215, 0.285)   // bottom-left  (circle: start)
    let b = p(0.215, 0.705)   // top-left     (box)
    let c = p(0.500, 0.430)   // middle       (diamond: decision)
    let d = p(0.785, 0.705)   // top-right    (box)
    let e = p(0.785, 0.285)   // bottom-right (circle: end)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.012), blur: u * 0.03, color: color(0x000000, 0.28))

    // Edges.
    ctx.setStrokeColor(color(0xffffff))
    ctx.setLineWidth(u * 0.055)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: a); ctx.addLine(to: b); ctx.addLine(to: c); ctx.addLine(to: d); ctx.addLine(to: e)
    ctx.strokePath()

    // Nodes.
    ctx.setFillColor(color(0xffffff))
    let rCircle = u * 0.088
    ctx.fillEllipse(in: CGRect(x: a.x - rCircle, y: a.y - rCircle, width: rCircle * 2, height: rCircle * 2))
    ctx.fillEllipse(in: CGRect(x: e.x - rCircle, y: e.y - rCircle, width: rCircle * 2, height: rCircle * 2))

    let half = u * 0.085
    for center in [b, d] {
        let rect = CGRect(x: center.x - half, y: center.y - half, width: half * 2, height: half * 2)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: u * 0.03, cornerHeight: u * 0.03, transform: nil))
        ctx.fillPath()
    }

    let dg = u * 0.118
    ctx.move(to: CGPoint(x: c.x, y: c.y + dg))
    ctx.addLine(to: CGPoint(x: c.x + dg, y: c.y))
    ctx.addLine(to: CGPoint(x: c.x, y: c.y - dg))
    ctx.addLine(to: CGPoint(x: c.x - dg, y: c.y))
    ctx.closePath()
    ctx.fillPath()
    ctx.restoreGState()

    // Inner accents on nodes so they read as "nodes", not blobs.
    ctx.setFillColor(color(0x4b3fe0))
    let rInner = u * 0.036
    for center in [a, e] {
        ctx.fillEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2, height: rInner * 2))
    }
    ctx.setFillColor(color(0x5a4cf0))
    let ih = u * 0.034
    for center in [b, d] {
        let rect = CGRect(x: center.x - ih, y: center.y - ih, width: ih * 2, height: ih * 2)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: u * 0.012, cornerHeight: u * 0.012, transform: nil))
        ctx.fillPath()
    }
    ctx.setFillColor(color(0x1fb8a6))
    let idg = u * 0.05
    ctx.move(to: CGPoint(x: c.x, y: c.y + idg))
    ctx.addLine(to: CGPoint(x: c.x + idg, y: c.y))
    ctx.addLine(to: CGPoint(x: c.x, y: c.y - idg))
    ctx.addLine(to: CGPoint(x: c.x - idg, y: c.y))
    ctx.closePath()
    ctx.fillPath()
}

func renderPNG(size: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(size: CGFloat(size), in: ctx)
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])!
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in outputs {
    let url = outDir.appendingPathComponent(name)
    try renderPNG(size: size).write(to: url)
    print("wrote \(name)")
}
if args.count >= 3 {
    try renderPNG(size: 1024).write(to: URL(fileURLWithPath: args[2]))
    print("wrote preview \(args[2])")
}
