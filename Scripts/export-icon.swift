#!/usr/bin/env swift
import AppKit
import CoreImage
import Foundation

// Export the approved transparent liquid-glass bottle for the app and website.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manager = FileManager.default
let source = root.appendingPathComponent("Assets/Artwork/Schnaps-Liquid-Glass.png")
let sourceData = try Data(contentsOf: source)
func render(_ artwork: NSImage, pixels: Int, insetFraction: CGFloat = 0) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    CGRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    artwork.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels)
        .insetBy(dx: CGFloat(pixels) * insetFraction, dy: CGFloat(pixels) * insetFraction))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
let artwork = NSImage(data: sourceData)!
let previews = root.appendingPathComponent("Assets/Previews")
try manager.createDirectory(at: previews, withIntermediateDirectories: true)
// Deeper glass midtones retain the specular highlights and saturated blueprint rails.
// Core Image operates on unpremultiplied color; the original transparency is preserved.
let image = CIImage(data: sourceData)!
let darkImage = image.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 1.8])
let darkBitmap = NSBitmapImageRep(cgImage: CIContext().createCGImage(darkImage, from: image.extent)!)
let darkData = darkBitmap.representation(using: .png, properties: [:])!
let darkArtwork = NSImage(data: darkData)!
// Icon Composer places layers on the system icon plate; leave room for its safe area.
try render(artwork, pixels: 1024, insetFraction: 0.10)
    .write(to: root.appendingPathComponent("Assets/Schnaps.icon/Assets/Schnaps-Glass.png"))
try render(artwork, pixels: 512).write(to: previews.appendingPathComponent("Schnaps.png"))
try render(darkArtwork, pixels: 512).write(to: previews.appendingPathComponent("Schnaps-Dark.png"))
// Keep the established preview filenames used by About and documentation.
try render(artwork, pixels: 512).write(to: previews.appendingPathComponent("Schnaps-Mono.png"))
let website = root.appendingPathComponent("website/dist/assets")
try render(artwork, pixels: 512).write(to: website.appendingPathComponent("logo.png"))
try render(artwork, pixels: 512).write(to: website.appendingPathComponent("icon.png"))
func exportIcon(_ artwork: NSImage, name: String) throws {
    let iconset = root.appendingPathComponent("build/IconExport/\(name).iconset")
    try manager.createDirectory(at: iconset, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for multiplier in [1, 2] {
            let name = "icon_\(size)x\(size)\(multiplier == 2 ? "@2x" : "").png"
            try render(artwork, pixels: size * multiplier).write(to: iconset.appendingPathComponent(name))
        }
    }
    try manager.createDirectory(at: root.appendingPathComponent("Assets/Compiled"), withIntermediateDirectories: true)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Assets/Compiled/\(name).icns").path]
    try process.run()
    process.waitUntilExit()
    precondition(process.terminationStatus == 0, "iconutil failed")
}
try exportIcon(artwork, name: "Schnaps-Mark")
try exportIcon(artwork, name: "Schnaps")
try exportIcon(darkArtwork, name: "Schnaps-Dark")
try exportIcon(darkArtwork, name: "Schnaps-Mark-Dark")
try render(artwork, pixels: 512).write(to: previews.appendingPathComponent("Schnaps-Dock.png"))
// Keep compiled assets in source control so packaging also works with Xcode 16.
// Regeneration requires Xcode 26's Icon Composer support.
let compiled = root.appendingPathComponent("build/IconExport/Compiled")
try manager.createDirectory(at: compiled, withIntermediateDirectories: true)
let compiler = Process()
compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
compiler.arguments = ["actool", root.appendingPathComponent("Assets/Schnaps.icon").path,
    "--compile", compiled.path, "--platform", "macosx", "--minimum-deployment-target", "14.0",
    "--app-icon", "Schnaps", "--output-partial-info-plist", compiled.appendingPathComponent("Info.plist").path]
try compiler.run()
compiler.waitUntilExit()
precondition(compiler.terminationStatus == 0, "Icon Composer compilation requires Xcode 26 or later")
let catalog = root.appendingPathComponent("Assets/Compiled/Assets.car")
if manager.fileExists(atPath: catalog.path) { try manager.removeItem(at: catalog) }
try manager.copyItem(at: compiled.appendingPathComponent("Assets.car"), to: catalog)
print("Exported light/dark transparent ICNS files and adaptive Icon Composer catalog.")
