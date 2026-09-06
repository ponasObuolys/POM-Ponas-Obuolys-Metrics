#!/usr/bin/env swift
import AppKit
import Foundation

_ = NSApplication.shared

// Reuse POM's existing artwork. No external downloads or provider requests.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let companion = root.appendingPathComponent("Apps/POMCompanion")
let resources = companion.appendingPathComponent("Sources/POMCompanionUI/Resources")
let assetRoot = companion.appendingPathComponent("App/Assets.xcassets")
let appIcon = assetRoot.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIcon, withIntermediateDirectories: true)

func png(_ image: NSImage, size: Int, opaque: Bool) -> Data {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    if opaque { NSColor(srgbRed: 0.08, green: 0.10, blue: 0.13, alpha: 1).setFill(); rect.fill() }
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}
for name in ["anthropic", "chatgpt"] {
    let source = root.appendingPathComponent("Sources/POM/Resources/\(name).svg")
    guard let image = NSImage(contentsOf: source) else { fatalError("Unable to read \(name) artwork") }
    try png(image, size: 144, opaque: false).write(to: resources.appendingPathComponent("\(name).png"))
}
try Data(contentsOf: root.appendingPathComponent("Sources/POM/Resources/THIRD-PARTY-NOTICES.txt"))
    .write(to: resources.appendingPathComponent("THIRD-PARTY-NOTICES.txt"))
var images: [[String: String]] = []
let iconset = root.appendingPathComponent(".build/companion-icon.iconset")
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try Data(contentsOf: iconset.appendingPathComponent(filename)).write(to: appIcon.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let large = NSImage(contentsOf: iconset.appendingPathComponent("icon_512x512@2x.png"))!
try png(large, size: 1024, opaque: true).write(to: appIcon.appendingPathComponent("ios-1024.png"))
images.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png"])
try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    .write(to: appIcon.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    .write(to: assetRoot.appendingPathComponent("Contents.json"))
print("Existing POM icon and provider marks prepared for both platforms.")
