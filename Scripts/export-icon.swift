#!/usr/bin/env swift
import AppKit
import Foundation

// Export the sculptural glass app icon and the separate transparent brand mark.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manager = FileManager.default
let source = root.appendingPathComponent("Assets/Artwork/Schnaps-Blueprint.svg")
let svg = try String(contentsOf: source, encoding: .utf8)
func render(_ artwork: NSImage, pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    CGRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    artwork.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
let artwork = NSImage(data: Data(svg.utf8))!
let previews = root.appendingPathComponent("Assets/Previews")
try manager.createDirectory(at: previews, withIntermediateDirectories: true)
for name in ["Schnaps", "Schnaps-Dark"] {
    try render(artwork, pixels: 512).write(to: previews.appendingPathComponent("\(name).png"))
}
let mono = NSImage(data: Data(svg.replacingOccurrences(of: "#508ec5", with: "#73777f").utf8))!
try render(mono, pixels: 512).write(to: previews.appendingPathComponent("Schnaps-Mono.png"))
let website = root.appendingPathComponent("website/dist/assets")
try Data(svg.utf8).write(to: website.appendingPathComponent("logo.svg"))
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
let dock = NSImage(contentsOf: root.appendingPathComponent("Assets/Artwork/Schnaps-Dock.png"))!
try exportIcon(dock, name: "Schnaps")
try render(dock, pixels: 512).write(to: previews.appendingPathComponent("Schnaps-Dock.png"))
print("Exported sculptural Dock icon and transparent brand mark at 16–1024 px.")
