#!/usr/bin/env swift
import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Assets/ProductHunt")
let mark = NSImage(contentsOf: root.appendingPathComponent("Assets/Artwork/Schnaps-Blueprint.svg"))!
// Native live hover renders and actual area/pinning captures from the homepage demo.
let overview = NSImage(contentsOf: output.appendingPathComponent("Source/overview.png"))!
let hover = NSImage(contentsOf: output.appendingPathComponent("Source/hover.png"))!
let selection = NSImage(contentsOf: output.appendingPathComponent("Source/pin.png"))!
let icon = NSImage(contentsOf: root.appendingPathComponent("Assets/Artwork/Schnaps-Dock.png"))!

struct HuntCard: View {
    let screenshot: NSImage
    let number: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.045, green: 0.06, blue: 0.10)
            RadialGradient(colors: [.blue.opacity(0.16), .clear], center: .trailing, startRadius: 0, endRadius: 850)
            RadialGradient(colors: [.purple.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 650)
            HStack(spacing: 10) {
                Image(nsImage: mark).resizable().scaledToFit().frame(width: 38, height: 38)
                Text("Schnaps").font(.system(size: 25, weight: .semibold)).tracking(-0.6)
            }.foregroundStyle(.white).offset(x: 60, y: 48)
            Text(number).font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35)).offset(x: 1150, y: 62)
            Image(nsImage: screenshot).resizable().interpolation(.high).scaledToFit()
                .frame(width: 650, height: 690).offset(x: 310, y: 42)
            Text("getschnaps.com").font(.system(size: 15)).foregroundStyle(.white.opacity(0.45))
                .offset(x: 60, y: 710)
        }.frame(width: 1270, height: 760).clipped()
    }
}

try MainActor.assumeIsolated {
    @MainActor func save<V: View>(_ view: V, name: String, size: CGSize) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else { fatalError("Rendering failed: \(name)") }
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        precondition(png.count < 3_000_000)
        try png.write(to: output.appendingPathComponent(name + ".png"))
        print("\(name): \(image.width) × \(image.height), \(png.count) bytes")
    }
    let cards = [
        ("01-overview", overview),
        ("02-find-dimensions", hover),
        ("03-pin-and-copy", selection)
    ]
    for (index, card) in cards.enumerated() {
        try save(HuntCard(screenshot: card.1, number: "0\(index + 1) / 03"), name: card.0, size: CGSize(width: 1270, height: 760))
    }
    struct Frame: Decodable { let file: String; let duration: Int }
    let source = output.appendingPathComponent("Source")
    let timeline = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: source.appendingPathComponent("timeline.json")))
    // Lead with visible Find Dimensions axes for a useful static sharing preview.
    let ordered = Array(timeline.dropFirst()) + [timeline[0]]
    let gifURL = output.appendingPathComponent("01-demo.gif")
    let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, ordered.count, nil)!
    CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in ordered {
        let image = NSImage(contentsOf: source.appendingPathComponent("Frames/" + frame.file))!
        let renderer = ImageRenderer(content: HuntCard(screenshot: image, number: "01 / 03"))
        renderer.scale = 1; renderer.isOpaque = true
        CGImageDestinationAddImage(gif, renderer.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: Double(frame.duration) / 1000]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(gif))
    let gifBytes = try Data(contentsOf: gifURL).count
    precondition(gifBytes < 10_000_000)
    print("01-demo.gif: 1270 × 760, \(gifBytes) bytes, looping")
    try save(Image(nsImage: icon).resizable().scaledToFit(), name: "thumbnail", size: CGSize(width: 240, height: 240))
}
