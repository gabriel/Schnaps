#!/usr/bin/env swift
import AppKit
import Foundation

// A Swift-only build/packaging entry point. Run from the repository root.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let configuration = CommandLine.arguments.contains("--debug") ? "debug" : "release"
let manager = FileManager.default
func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: executable, code: Int(process.terminationStatus)) }
}
try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration])
let app = root.appendingPathComponent("build/Schnap.app")
let contents = app.appendingPathComponent("Contents")
let resources = contents.appendingPathComponent("Resources")
try manager.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
let binary = contents.appendingPathComponent("MacOS/Schnap")
if manager.fileExists(atPath: binary.path) { try manager.removeItem(at: binary) }
try manager.copyItem(at: root.appendingPathComponent(".build/\(configuration)/Schnap"), to: binary)
let info: [String: Any] = [
    "CFBundleIdentifier": "com.gabrielhandford.Schnap",
    "CFBundleName": "Schnap", "CFBundleDisplayName": "Schnap",
    "CFBundleExecutable": "Schnap", "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
    "CFBundleIconFile": "Schnap", "LSMinimumSystemVersion": "14.0",
    "LSUIElement": true, "NSHighResolutionCapable": true,
    "NSScreenCaptureUsageDescription": "Schnap uses a still image of your displays to detect edges and measure screen elements. Images remain in memory on your Mac."
]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    .write(to: contents.appendingPathComponent("Info.plist"))

let iconset = root.appendingPathComponent("build/Schnap.iconset")
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let pixels = size * multiplier
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 512, y: CGFloat(pixels) / 512)
        NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: 16, y: 16, width: 480, height: 480), xRadius: 110, yRadius: 110).fill()
        NSColor.systemMint.setStroke()
        let box = NSBezierPath(roundedRect: CGRect(x: 112, y: 130, width: 288, height: 252), xRadius: 8, yRadius: 8)
        box.lineWidth = 12; box.stroke()
        let ticks = NSBezierPath()
        ticks.lineWidth = 8
        for x in stride(from: 148, through: 364, by: 36) {
            ticks.move(to: CGPoint(x: x, y: 382))
            ticks.line(to: CGPoint(x: x, y: x % 72 == 4 ? 330 : 350))
        }
        ticks.stroke()
        for point in [CGPoint(x: 112, y: 130), CGPoint(x: 400, y: 382)] {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30), xRadius: 4, yRadius: 4).fill()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let filename = "icon_\(size)x\(size)\(multiplier == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("Schnap.icns").path])
let identity = ProcessInfo.processInfo.environment["SCHNAP_SIGN_IDENTITY"] ?? "-"
try run("/usr/bin/codesign", ["--force", "--sign", identity, "--timestamp=none", app.path])
print("Built \(app.path)")
