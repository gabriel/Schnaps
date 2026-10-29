#!/usr/bin/env swift
import AppKit
import SwiftUI

// Export native-size product artwork from existing Schnaps branding and captures.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Assets/ProductMedia")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bottle = NSImage(contentsOf: root.appendingPathComponent("Assets/Artwork/Schnaps-Blueprint.svg"))!
let demo = NSImage(contentsOf: root.appendingPathComponent("website/dist/assets/schnaps-demo-poster.webp"))!

struct ProductCard: View {
    let dark: Bool
    let inAction: Bool
    let bottle: NSImage
    let demo: NSImage
    private var ink: Color { dark ? Color(red: 0.95, green: 0.97, blue: 1) : Color(red: 0.08, green: 0.14, blue: 0.22) }
    private var secondary: Color { dark ? Color(red: 0.62, green: 0.70, blue: 0.80) : Color(red: 0.37, green: 0.44, blue: 0.53) }
    private var blue: Color { Color(red: 0.40, green: 0.72, blue: 0.94) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            (dark ? Color(red: 0.045, green: 0.065, blue: 0.10) : Color(red: 0.97, green: 0.98, blue: 1))
            RadialGradient(colors: [blue.opacity(dark ? 0.14 : 0.10), .clear], center: .init(x: 0.74, y: 0.45), startRadius: 0, endRadius: 850)
            RadialGradient(colors: [Color.purple.opacity(dark ? 0.08 : 0.035), .clear], center: .topLeading, startRadius: 0, endRadius: 1000)
            Canvas { context, _ in
                var grid = Path()
                for x in stride(from: 48, through: 1600, by: 48) {
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: 1200))
                }
                for y in stride(from: 0, through: 1200, by: 48) {
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: 1600, y: y))
                }
                context.stroke(grid, with: .color(blue.opacity(dark ? 0.025 : 0.045)), lineWidth: 1)
                var guides = Path()
                guides.move(to: CGPoint(x: 72, y: 182)); guides.addLine(to: CGPoint(x: 1528, y: 182))
                guides.move(to: CGPoint(x: 72, y: 1040)); guides.addLine(to: CGPoint(x: 1528, y: 1040))
                for x in [72, 1528] {
                    for y in [182, 1040] {
                        guides.move(to: CGPoint(x: x, y: y - 10)); guides.addLine(to: CGPoint(x: x, y: y + 10))
                    }
                }
                context.stroke(guides, with: .color(blue.opacity(dark ? 0.18 : 0.22)), lineWidth: 1)
            }
            HStack(spacing: 14) {
                Image(nsImage: bottle).resizable().scaledToFit().frame(width: 48, height: 48)
                Text("Schnaps").font(.system(size: 28, weight: .semibold)).tracking(-0.6)
            }
            .foregroundStyle(ink).offset(x: 72, y: 70)
            Text(inAction ? "THE LITTLE MAC MEASURING APP" : "A LITTLE EXTRA SPIRIT")
                .font(.system(size: 16, weight: .medium, design: .monospaced)).tracking(2)
                .foregroundStyle(secondary).offset(x: 72, y: 280)
            VStack(alignment: .leading, spacing: 24) {
                Text(inAction ? "Get the\ndetails right." : "Schnaps\nPro.")
                    .font(.system(size: inAction ? 88 : 108, weight: .semibold)).tracking(-5)
                    .lineSpacing(-3).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(ink)
                Text(inAction ? "Find dimensions.\nMeasure gaps.\nKeep the details." : "Excellent taste.")
                    .font(.system(size: inAction ? 30 : 34, weight: .regular)).lineSpacing(8)
                    .foregroundStyle(secondary)
                if !inAction {
                    HStack(spacing: 16) {
                        ForEach(["Sip", "Pour", "Reserve"], id: \.self) { name in
                            Text(name).font(.system(size: 19, weight: .medium))
                                .foregroundStyle(ink.opacity(0.85))
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(blue.opacity(dark ? 0.07 : 0.06), in: Capsule())
                                .overlay(Capsule().strokeBorder(blue.opacity(0.18), lineWidth: 1))
                        }
                    }.padding(.top, 20)
                }
            }
            .frame(width: 680, alignment: .leading).offset(x: 72, y: 340)
            if inAction {
                Image(nsImage: demo).resizable().interpolation(.high).scaledToFit()
                    .frame(width: 610, height: 773).offset(x: 855, y: 228)
            } else {
                Image(nsImage: bottle).resizable().scaledToFit()
                    .brightness(dark ? 0.14 : 0).frame(width: 720, height: 720)
                    .offset(x: 800, y: 245)
            }
            HStack {
                Text("All the tools. Always free.")
                Spacer()
                Text("getschnaps.com").foregroundStyle(ink.opacity(0.8))
            }
            .font(.system(size: 20)).foregroundStyle(secondary)
            .frame(width: 1456).offset(x: 72, y: 1080)
        }
        .frame(width: 1600, height: 1200)
        .clipped()
    }
}

try MainActor.assumeIsolated {
    for (name, dark, inAction) in [
        ("01-schnaps-pro-dark", true, false),
        ("02-schnaps-pro-light", false, false),
        ("03-schnaps-in-action", true, true)
    ] {
        let renderer = ImageRenderer(content: ProductCard(dark: dark, inAction: inAction, bottle: bottle, demo: demo))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else { fatalError("Could not render \(name)") }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        precondition(bitmap.pixelsWide == 1600 && bitmap.pixelsHigh == 1200)
        let png = bitmap.representation(using: .png, properties: [:])!
        precondition(png.count < 10_000_000)
        try png.write(to: output.appendingPathComponent(name + ".png"))
        print("\(name).png: 1600 × 1200, \(png.count) bytes")
    }
}
