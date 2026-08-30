#!/usr/bin/env swift

import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let projectURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let resourceURL = projectURL.appendingPathComponent("Sources/Plainleaf/Resources", isDirectory: true)
let iconsetURL = resourceURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let outputURL = resourceURL.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
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

func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()

    let scale = CGFloat(pixels)
    let cardRect = NSRect(x: scale * 0.055, y: scale * 0.055, width: scale * 0.89, height: scale * 0.89)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: scale * 0.205, yRadius: scale * 0.205)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = scale * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -scale * 0.018)
    shadow.set()
    NSColor(calibratedRed: 0.235, green: 0.39, blue: 0.29, alpha: 1).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: scale * 0.27, y: scale * 0.29))
    leaf.curve(
        to: NSPoint(x: scale * 0.75, y: scale * 0.76),
        controlPoint1: NSPoint(x: scale * 0.30, y: scale * 0.62),
        controlPoint2: NSPoint(x: scale * 0.58, y: scale * 0.76)
    )
    leaf.curve(
        to: NSPoint(x: scale * 0.27, y: scale * 0.29),
        controlPoint1: NSPoint(x: scale * 0.73, y: scale * 0.43),
        controlPoint2: NSPoint(x: scale * 0.50, y: scale * 0.27)
    )
    leaf.close()
    NSColor(calibratedRed: 0.972, green: 0.947, blue: 0.875, alpha: 1).setFill()
    leaf.fill()

    let vein = NSBezierPath()
    vein.move(to: NSPoint(x: scale * 0.33, y: scale * 0.35))
    vein.curve(
        to: NSPoint(x: scale * 0.67, y: scale * 0.67),
        controlPoint1: NSPoint(x: scale * 0.43, y: scale * 0.45),
        controlPoint2: NSPoint(x: scale * 0.57, y: scale * 0.57)
    )
    vein.lineWidth = max(1.0, scale * 0.035)
    vein.lineCapStyle = .round
    NSColor(calibratedRed: 0.235, green: 0.39, blue: 0.29, alpha: 1).setStroke()
    vein.stroke()

    let markdownLine = NSBezierPath()
    markdownLine.move(to: NSPoint(x: scale * 0.32, y: scale * 0.22))
    markdownLine.line(to: NSPoint(x: scale * 0.56, y: scale * 0.22))
    markdownLine.lineWidth = max(1.0, scale * 0.026)
    markdownLine.lineCapStyle = .round
    NSColor(calibratedRed: 0.972, green: 0.947, blue: 0.875, alpha: 0.82).setStroke()
    markdownLine.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

for variant in variants {
    let png = try drawIcon(pixels: variant.pixels)
    try png.write(to: iconsetURL.appendingPathComponent(variant.name), options: [.atomic])
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", iconsetURL.path, "--output", outputURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}

print(outputURL.path)
