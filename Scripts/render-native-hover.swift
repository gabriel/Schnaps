#!/usr/bin/env swift
// Render every drawing-demo frame with the app's unmodified MeasurementView and edge detector.
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
let verifyOnly = CommandLine.arguments.contains("--verify-only")
let fixture = #"""
import AppKit
import MeasurementCore
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let verifyOnly = CommandLine.arguments.contains("--verify-only")
try MainActor.assumeIsolated {
    // Registered defaults belong only to this fixture process; the installed app's preferences are untouched.
    UserDefaults.standard.register(defaults: MeasurementPreferences.defaults)
    UserDefaults.standard.register(defaults: [
        PreferenceKey.unit: "px", PreferenceKey.tolerance: 36,
        PreferenceKey.overlayColor: "AF52DEFF", PreferenceKey.guideColor: "FF9F0AFF",
        PreferenceKey.autoContrast: false, PreferenceKey.aspectArea: false,
        PreferenceKey.aspectDistance: false, PreferenceKey.animations: false
    ])
    let data = try Data(contentsOf: root.appendingPathComponent("Assets/Previews/Schnaps-Drawing-Subject.png"))
    let image = NSBitmapImageRep(data: data)!.cgImage!
    let snapshot = ScreenSnapshot(image: image, pixels: PixelBuffer(image: image)!, scaleX: 2, scaleY: 2)
    @MainActor func makeView(_ mode: MeasurementMode) -> MeasurementView {
        let view = MeasurementView(frame: CGRect(x: 0, y: 0, width: 440, height: 520), scale: 2, snapshot: snapshot, mode: mode)
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    @MainActor func render(_ view: MeasurementView, named name: String) throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 880, pixelsHigh: 1040, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 880 * 4, bitsPerPixel: 32)!
        bitmap.size = view.bounds.size
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
        }
        // The clean subject and native view contain no captured pointer or cursor halo.
        // Do not composite NSCursor artwork onto the export.
        let output = root.appendingPathComponent(verifyOnly ? "build/NativeHover/\(name).png" : "website/media-source/drawing-frames/\(name).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        print("\(name): \(view.accessibilityValue() ?? "")")
    }
    @MainActor func mouse(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: CGPoint(x: point.x, y: 520 - point.y), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    let view = makeView(.findDimensions)
    for (name, point) in [("01-hover", CGPoint(x: 180, y: 150)), ("02-hover", CGPoint(x: 350, y: 240))] {
        view.mouseMoved(with: mouse(.mouseMoved, at: point))
        try render(view, named: name)
    }
    // Unit-test the actual canvas key handler without sending input to any application.
    var captures: [(CGRect,Bool,Bool)] = []
    view.onCapture = { captures.append(($0,$1,$2)) }
    for (key,code,flags) in [("c",UInt16(8),NSEvent.ModifierFlags()),("p",UInt16(35),NSEvent.ModifierFlags.option)] {
        let event=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:flags,timestamp:0,windowNumber:0,
                                  context:nil,characters:key,charactersIgnoringModifiers:key,isARepeat:false,keyCode:code)!
        view.keyDown(with:event)
    }
    precondition(captures.count == 2 && captures[0].1 && !captures[0].2 && !captures[1].1 && captures[1].2)
    precondition(captures.allSatisfy { $0.0.width > 0 && $0.0.height > 0 })
    print("Native screenshot shortcuts: C copies; Option-P saves with toggled padding")

    let area = makeView(.area)
    try render(area, named: "00-base")
    area.mouseDown(with: mouse(.leftMouseDown, at: CGPoint(x: 98, y: 225.5)))
    for (name, point) in [("03-small", CGPoint(x: 158, y: 270)),
                          ("03-medium", CGPoint(x: 240, y: 320)),
                          ("04-area", CGPoint(x: 323, y: 365.5))] {
        area.mouseDragged(with: mouse(.leftMouseDragged, at: point))
        if name == "04-area" { area.mouseUp(with: mouse(.leftMouseUp, at: point)) }
        try render(area, named: name)
    }
    precondition(area.accessibilityValue() as? String == "450 × 280 px")
    let pin = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                              context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49)!
    area.keyDown(with: pin)
    precondition(area.pinned == [CGRect(x: 98, y: 225.5, width: 225, height: 140)])
    // Export the settled pin state after the app's brief action feedback disappears.
    RunLoop.current.run(until: Date().addingTimeInterval(2.1))
    try render(area, named: "05-pinned")
}
"""#
try fixture.write(to: build.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
let core = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Sources/MeasurementCore"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }.map(\.path)
try run(["swiftc", "-emit-library", "-emit-module", "-module-name", "MeasurementCore"] + core + ["-o", build.appendingPathComponent("libMeasurementCore.dylib").path, "-emit-module-path", build.appendingPathComponent("MeasurementCore.swiftmodule").path])
try run(["swiftc", "-I", build.path, "-L", build.path, "-lMeasurementCore", "-Xlinker", "-rpath", "-Xlinker", build.path, root.appendingPathComponent("Sources/Schnaps/MeasurementPreferences.swift").path, root.appendingPathComponent("Sources/Schnaps/Localization.swift").path, build.appendingPathComponent("AppMeasurementView.swift").path, build.appendingPathComponent("main.swift").path, "-o", build.appendingPathComponent("render").path])
try run([build.appendingPathComponent("render").path] + (verifyOnly ? ["--verify-only"] : []))
