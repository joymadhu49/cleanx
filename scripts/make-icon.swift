#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// CleanX app icon — programmatically rendered.
// Design: rounded-square dark gradient backdrop, four white viewfinder
// corner brackets framing an inner area, accent diagonal slash "X".

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> Data? {
    let s = Int(size)
    guard let ctx = CGContext(
        data: nil, width: s, height: s,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset: CGFloat = size * 0.08
    let bg = rect.insetBy(dx: inset, dy: inset)
    let corner: CGFloat = bg.width * 0.225

    // Background rounded rect — radial gradient: deep indigo → teal
    let path = CGPath(roundedRect: bg, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [
        CGColor(red: 0.07, green: 0.10, blue: 0.22, alpha: 1),
        CGColor(red: 0.12, green: 0.36, blue: 0.55, alpha: 1),
        CGColor(red: 0.20, green: 0.72, blue: 0.74, alpha: 1)
    ] as CFArray
    let locs: [CGFloat] = [0.0, 0.55, 1.0]
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: bg.minX, y: bg.maxY),
            end: CGPoint(x: bg.maxX, y: bg.minY),
            options: []
        )
    }
    // Subtle highlight
    let hi = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [CGColor(gray: 1.0, alpha: 0.18), CGColor(gray: 1.0, alpha: 0.0)] as CFArray,
                        locations: [0.0, 0.6])!
    ctx.drawRadialGradient(hi,
                           startCenter: CGPoint(x: bg.minX + bg.width * 0.30, y: bg.maxY - bg.height * 0.18),
                           startRadius: 0,
                           endCenter: CGPoint(x: bg.minX + bg.width * 0.30, y: bg.maxY - bg.height * 0.18),
                           endRadius: bg.width * 0.6,
                           options: [])
    ctx.restoreGState()

    // Viewfinder corner brackets
    let lineW = bg.width * 0.055
    let armLen = bg.width * 0.18
    let bracketInset = bg.width * 0.18
    let inner = bg.insetBy(dx: bracketInset, dy: bracketInset)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    ctx.setLineWidth(lineW)
    ctx.setLineCap(.round)

    func bracket(at p: CGPoint, hDir: CGFloat, vDir: CGFloat) {
        ctx.move(to: CGPoint(x: p.x + hDir * armLen, y: p.y))
        ctx.addLine(to: p)
        ctx.addLine(to: CGPoint(x: p.x, y: p.y + vDir * armLen))
    }
    bracket(at: CGPoint(x: inner.minX, y: inner.maxY), hDir: 1, vDir: -1) // top-left
    bracket(at: CGPoint(x: inner.maxX, y: inner.maxY), hDir: -1, vDir: -1) // top-right
    bracket(at: CGPoint(x: inner.minX, y: inner.minY), hDir: 1, vDir: 1) // bottom-left
    bracket(at: CGPoint(x: inner.maxX, y: inner.minY), hDir: -1, vDir: 1) // bottom-right
    ctx.strokePath()

    // Central accent "X" — two thick rounded strokes, accent color
    let xInset = bg.width * 0.32
    let xRect = bg.insetBy(dx: xInset, dy: xInset)
    ctx.setLineWidth(bg.width * 0.075)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0))
    ctx.move(to: CGPoint(x: xRect.minX, y: xRect.minY))
    ctx.addLine(to: CGPoint(x: xRect.maxX, y: xRect.maxY))
    ctx.move(to: CGPoint(x: xRect.maxX, y: xRect.minY))
    ctx.addLine(to: CGPoint(x: xRect.minX, y: xRect.maxY))
    ctx.strokePath()

    // Soft drop shadow on bg edge (drawn after, as inner shadow approx)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.25))
    ctx.setLineWidth(1.0)
    ctx.strokePath()
    ctx.restoreGState()

    guard let cg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cg)
    return rep.representation(using: .png, properties: [:])
}

let pairs: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]
for p in pairs {
    if let data = drawIcon(size: p.size) {
        let url = URL(fileURLWithPath: outDir).appendingPathComponent(p.name)
        try? data.write(to: url)
        print("wrote \(p.name) (\(Int(p.size))px)")
    }
}
