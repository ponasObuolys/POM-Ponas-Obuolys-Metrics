#!/usr/bin/env swift
import AppKit
import Foundation

// Nupiešia POM ikoną visiems reikalingiems dydžiams ir sudeda į .iconset katalogą.
// Motyvas tas pats, kaip meniu juostoje: dvi juostelės, viena virš kitos.

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("Naudojimas: make-icon.swift <iconset katalogas>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func color(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

let backgroundTop = color(0.14, 0.17, 0.21)
let backgroundBottom = color(0.05, 0.06, 0.08)
let trackColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.13)
let greenColor = color(0.29, 0.84, 0.55)
let amberColor = color(0.98, 0.75, 0.25)

func drawIcon(pixels: Int) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    // Ikona piešiama su nedideliu paraščiu, kaip įprasta macOS programoms.
    let inset = size * 0.06
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = plate.width * 0.2237

    let plateShape = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)
    NSGradient(starting: backgroundTop, ending: backgroundBottom)?
        .draw(in: plateShape, angle: -90)

    // Švelnus šviesos kraštas viršuje
    plateShape.lineWidth = size * 0.006
    NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10).setStroke()
    plateShape.stroke()

    let barWidth = plate.width * 0.62
    let barHeight = plate.height * 0.105
    let barX = plate.minX + (plate.width - barWidth) / 2
    let gap = plate.height * 0.10
    let centerY = plate.midY

    func drawBar(y: CGFloat, fraction: CGFloat, fill: NSColor) {
        let track = NSRect(x: barX, y: y, width: barWidth, height: barHeight)
        let trackShape = NSBezierPath(
            roundedRect: track, xRadius: barHeight / 2, yRadius: barHeight / 2)
        trackColor.setFill()
        trackShape.fill()

        let filled = NSRect(x: barX, y: y, width: barWidth * fraction, height: barHeight)
        let filledShape = NSBezierPath(
            roundedRect: filled, xRadius: barHeight / 2, yRadius: barHeight / 2)
        fill.setFill()
        filledShape.fill()
    }

    drawBar(y: centerY + gap / 2, fraction: 0.38, fill: greenColor)
    drawBar(y: centerY - gap / 2 - barHeight, fraction: 0.72, fill: amberColor)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

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
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let data = drawIcon(pixels: variant.pixels) else {
        FileHandle.standardError.write(Data("Nepavyko nupiešti \(variant.name)\n".utf8))
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(variant.name))
}

print("Ikonos nupieštos: \(outputDirectory.path)")
