#!/usr/bin/env swift
// Encode cropped, genuine Schnaps captures. No measurement UI is drawn here.
import AppKit
import Foundation

struct DemoFrame: Decodable { let file: String; let duration: Int }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("website/media-source/demo-frames")
let output = root.appendingPathComponent("website/dist/assets")
let frames = try JSONDecoder().decode([DemoFrame].self, from: Data(contentsOf: source.appendingPathComponent("timeline.json")))
var arguments = ["img2webp", "-min_size", "-loop", "0", "-lossy", "-q", "88", "-m", "6"]
for frame in frames {
    precondition(frame.duration > 0 && frame.file == URL(fileURLWithPath: frame.file).lastPathComponent)
    let path = source.appendingPathComponent(frame.file)
    let bitmap = NSBitmapImageRep(data: try Data(contentsOf: path))!
    precondition(bitmap.pixelsWide == 720 && bitmap.pixelsHigh == 912, "Keep captures at native 2× resolution.")
    arguments += ["-d", String(frame.duration), path.path]
}
arguments += ["-o", output.appendingPathComponent("schnaps-demo.webp").path]
let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
encoder.arguments = arguments
try encoder.run()
encoder.waitUntilExit()
precondition(encoder.terminationStatus == 0, "Install the WebP tools (img2webp) before exporting.")
let poster = NSBitmapImageRep(data: try Data(contentsOf: source.appendingPathComponent("01.png")))!
try poster.representation(using: .jpeg, properties: [.compressionFactor: 0.92])!
    .write(to: output.appendingPathComponent("schnaps-demo-poster.jpg"))
print("Exported a genuine \(frames.reduce(0) { $0 + $1.duration }) ms Calculator demo, 720 × 912 px (360 × 456 CSS px).")
