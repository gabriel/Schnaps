#!/usr/bin/env swift
// Render an offscreen fixture with the app's unmodified MeasurementView and edge detector.
// This does not launch, capture, or send input to any application.
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let build = root.appendingPathComponent("build/NativeHover")
try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
func read(_ path: String) throws -> String { try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) }
func run(_ args: [String]) throws {
    let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/env"); task.arguments = args
    try task.run(); task.waitUntilExit(); precondition(task.terminationStatus == 0)
}
let overlay = try read("Sources/Schnaps/Overlay.swift")
let view = String(overlay[overlay.range(of: "@MainActor\nfinal class MeasurementView")!.lowerBound...])
let settings = try read("Sources/Schnaps/Settings.swift")
let declarations = String(settings[settings.range(of: "enum MeasurementMode")!.lowerBound..<settings.range(of: "enum SettingsPane")!.lowerBound])
let snapshot = try read("Sources/Schnaps/ScreenSnapshot.swift")
let snapshotData = String(snapshot[snapshot.range(of: "struct ScreenSnapshot")!.lowerBound..<snapshot.range(of: "    @MainActor\n    static func capture")!.lowerBound]) + "}\n"
try ("import AppKit\nimport MeasurementCore\n" + declarations + snapshotData + view).write(to: build.appendingPathComponent("AppMeasurementView.swift"), atomically: true, encoding: .utf8)
let fixture = #"""
import AppKit
import MeasurementCore
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
try MainActor.assumeIsolated {
    // Registered defaults belong only to this fixture process; the installed app's preferences are untouched.
    UserDefaults.standard.register(defaults: [PreferenceKey.unit: "px", PreferenceKey.tolerance: 36])
    let data = try Data(contentsOf: root.appendingPathComponent("Assets/Previews/Schnaps-Drawing-Subject.png"))
    let image = NSBitmapImageRep(data: data)!.cgImage!
    let snapshot = ScreenSnapshot(image: image, pixels: PixelBuffer(image: image)!, scaleX: 2, scaleY: 2)
    let view = MeasurementView(frame: CGRect(x: 0, y: 0, width: 440, height: 520), scale: 2, snapshot: snapshot, mode: .findDimensions)
    view.appearance = NSAppearance(named: .darkAqua)
    for (name, point) in [("01-hover", CGPoint(x: 180, y: 370)), ("02-hover", CGPoint(x: 350, y: 280))] {
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        view.mouseMoved(with: event)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 880, pixelsHigh: 1040, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 880 * 4, bitsPerPixel: 32)!
        bitmap.size = view.bounds.size
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            let cursor = NSCursor.crosshair
            cursor.image.draw(at: CGPoint(x: point.x - cursor.hotSpot.x, y: point.y - cursor.hotSpot.y), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
        let output = root.appendingPathComponent("website/media-source/drawing-frames/\(name).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        print("\(name): \(view.accessibilityValue() ?? "")")
    }
}
"""#
try fixture.write(to: build.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
let core = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Sources/MeasurementCore"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }.map(\.path)
try run(["swiftc", "-emit-library", "-emit-module", "-module-name", "MeasurementCore"] + core + ["-o", build.appendingPathComponent("libMeasurementCore.dylib").path, "-emit-module-path", build.appendingPathComponent("MeasurementCore.swiftmodule").path])
try run(["swiftc", "-I", build.path, "-L", build.path, "-lMeasurementCore", "-Xlinker", "-rpath", "-Xlinker", build.path, build.appendingPathComponent("AppMeasurementView.swift").path, build.appendingPathComponent("main.swift").path, "-o", build.appendingPathComponent("render").path])
try run([build.appendingPathComponent("render").path])
