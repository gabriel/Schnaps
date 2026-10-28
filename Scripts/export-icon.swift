#!/usr/bin/env swift
import AppKit
import Foundation

// Regenerate reviewed previews and the full-resolution ICNS fallback from Icon Composer.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manager = FileManager.default
func run(_ executable: String, _ arguments: [String], capture: Bool = false) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    if capture { process.standardOutput = pipe }
    try process.run()
    let data = capture ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: executable, code: Int(process.terminationStatus)) }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}
let developer = URL(fileURLWithPath: try run("/usr/bin/xcode-select", ["-p"], capture: true))
let tool = developer.deletingLastPathComponent()
    .appendingPathComponent("Applications/Icon Composer.app/Contents/Executables/ictool")
let source = root.appendingPathComponent("Assets/Schnaps.icon")
let previews = root.appendingPathComponent("Assets/Previews")
try manager.createDirectory(at: previews, withIntermediateDirectories: true)
for (rendition, filename) in [("Default", "Schnaps"), ("Dark", "Schnaps-Dark"), ("Mono", "Schnaps-Mono")] {
    _ = try run(tool.path, [source.path, "--export-image", "--output-file", previews.appendingPathComponent("\(filename).png").path,
        "--platform", "macOS", "--rendition", rendition, "--width", "512", "--height", "512", "--scale", "1"])
}
let output = root.appendingPathComponent("build/IconExport")
try manager.createDirectory(at: output, withIntermediateDirectories: true)
let fullSize = output.appendingPathComponent("Schnaps.png")
_ = try run(tool.path, [source.path, "--export-image", "--output-file", fullSize.path,
    "--platform", "macOS", "--rendition", "Default", "--width", "1024", "--height", "1024", "--scale", "1"])
let artwork = NSImage(contentsOf: fullSize)!
let iconset = output.appendingPathComponent("Schnaps.iconset")
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let pixels = size * multiplier
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        // Match Apple's pre-Tahoe icon margins: an 832pt tile in a 1024pt canvas.
        let inset = CGFloat(pixels) * 96 / 1024
        artwork.draw(in: CGRect(x: inset, y: inset, width: CGFloat(pixels) - inset * 2, height: CGFloat(pixels) - inset * 2))
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(multiplier == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
try manager.createDirectory(at: root.appendingPathComponent("Assets/Compiled"), withIntermediateDirectories: true)
_ = try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Assets/Compiled/Schnaps.icns").path])
print("Exported Schnaps icon previews and 16–1024px ICNS representations.")
