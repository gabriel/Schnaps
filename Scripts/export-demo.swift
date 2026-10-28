#!/usr/bin/env swift
// Encode cropped, genuine Schnaps captures. No measurement UI is drawn here.
import AppKit
import Foundation

struct DemoFrame: Decodable { let file: String; let duration: Int }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("website/media-source/demo-frames")
let output = root.appendingPathComponent("website/dist/assets")
let staging = root.appendingPathComponent("build/DemoExport")
try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
let frames = try JSONDecoder().decode([DemoFrame].self, from: Data(contentsOf: source.appendingPathComponent("timeline.json")))

// Remove only the plain, edge-connected capture backdrop. Keep the actual app,
// cursor and measurement pixels, including antialiasing at the window boundary.
func clearBackdrop(_ image: NSBitmapImageRep) -> NSBitmapImageRep {
    let w = image.pixelsWide, h = image.pixelsHigh
    let result = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied,
        bytesPerRow: w * 4, bitsPerPixel: 32)!
    let pixels = result.bitmapData!
    let context = CGContext(data: pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
    let original = Array(UnsafeBufferPointer(start: pixels, count: w * h * 4))
    let background = Array(original[0..<3]).map(Int.init)
    func distance(_ index: Int) -> Int {
        let offset = index * 4
        return max(abs(Int(original[offset]) - background[0]),
                   abs(Int(original[offset + 1]) - background[1]),
                   abs(Int(original[offset + 2]) - background[2]))
    }
    var outside = [Bool](repeating: false, count: w * h)
    var queue: [Int] = []
    func visit(_ index: Int) {
        if !outside[index], distance(index) <= 32 { outside[index] = true; queue.append(index) }
    }
    for x in 0..<w { visit(x); visit((h - 1) * w + x) }
    for y in 0..<h { visit(y * w); visit(y * w + w - 1) }
    var head = 0
    while head < queue.count {
        let index = queue[head], x = index % w, y = index / w
        head += 1
        if x > 0 { visit(index - 1) }
        if x + 1 < w { visit(index + 1) }
        if y > 0 { visit(index - w) }
        if y + 1 < h { visit(index + w) }
    }
    for index in 0..<(w * h) {
        if outside[index] {
            for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
            continue
        }
        let x = index % w, y = index / w
        let touchesBackdrop = (x > 0 && outside[index - 1]) || (x + 1 < w && outside[index + 1])
            || (y > 0 && outside[index - w]) || (y + 1 < h && outside[index + w])
        guard touchesBackdrop else { continue }
        var maximum = distance(index)
        for yy in max(0, y - 1)...min(h - 1, y + 1) {
            for xx in max(0, x - 1)...min(w - 1, x + 1) {
                let neighbor = yy * w + xx
                maximum = max(maximum, distance(neighbor))
            }
        }
        if touchesBackdrop, maximum > 0 {
            let alpha = Double(distance(index)) / Double(maximum)
            for channel in 0..<3 {
                let value = (Double(original[index * 4 + channel]) - Double(background[channel]) * (1 - alpha)) / alpha
                pixels[index * 4 + channel] = UInt8(min(255, max(0, value.rounded())))
            }
            pixels[index * 4 + 3] = UInt8((alpha * 255).rounded())
        }
    }
    return result
}

var arguments = ["img2webp", "-min_size", "-mixed", "-loop", "0", "-q", "92", "-m", "6"]
var exported = Set<String>()
for frame in frames {
    precondition(frame.duration > 0 && frame.file == URL(fileURLWithPath: frame.file).lastPathComponent)
    let path = source.appendingPathComponent(frame.file)
    let bitmap = NSBitmapImageRep(data: try Data(contentsOf: path))!
    precondition(bitmap.pixelsWide == 720 && bitmap.pixelsHigh == 912, "Keep captures at native 2× resolution.")
    let transparent = staging.appendingPathComponent(frame.file)
    if exported.insert(frame.file).inserted {
        try clearBackdrop(bitmap).representation(using: .png, properties: [:])!.write(to: transparent)
    }
    arguments += ["-d", String(frame.duration), transparent.path]
}
arguments += ["-o", output.appendingPathComponent("schnaps-demo.webp").path]
let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
encoder.arguments = arguments
try encoder.run()
encoder.waitUntilExit()
precondition(encoder.terminationStatus == 0, "Install the WebP tools (img2webp) before exporting.")
let poster = Process()
poster.executableURL = URL(fileURLWithPath: "/usr/bin/env")
poster.arguments = ["cwebp", "-quiet", "-lossless", "-q", "75", "-m", "6", staging.appendingPathComponent("01.png").path,
    "-o", output.appendingPathComponent("schnaps-demo-poster.webp").path]
try poster.run()
poster.waitUntilExit()
precondition(poster.terminationStatus == 0, "Static WebP export failed.")
print("Exported a genuine \(frames.reduce(0) { $0 + $1.duration }) ms Calculator demo, 720 × 912 px (360 × 456 CSS px).")
