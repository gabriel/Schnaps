#!/usr/bin/env swift
import AppKit
import SwiftUI

// An explicitly illustrated feature demo, not a capture of a real application.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let staging = root.appendingPathComponent("build/IllustratedDemo")
let assets = root.appendingPathComponent("website/dist/assets")
try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

struct DemoState {
    var phase: Int
    var progress: CGFloat = 1
}

struct IllustratedDemo: View {
    let state: DemoState
    private let cyan = Color(red: 0.41, green: 0.81, blue: 1)
    private let orange = Color(red: 1, green: 0.69, blue: 0.32)
    private let secondary = Color(red: 0.60, green: 0.66, blue: 0.76)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.10, green: 0.13, blue: 0.19))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12)))
                .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
                .frame(width: 320, height: 390).offset(x: 60, y: 48)
            Text("Bespoke").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                .offset(x: 84, y: 70)
            Text("SAMPLE UI").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                .foregroundStyle(secondary).offset(x: 283, y: 73)
            RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(red: 0.39, green: 0.74, blue: 0.77), Color(red: 0.24, green: 0.51, blue: 0.64)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Text("J").font(.system(size: 22, weight: .medium)).foregroundStyle(.white))
                .frame(width: 44, height: 44).offset(x: 84, y: 112)
            VStack(alignment: .leading, spacing: 5) {
                Text("Fixie Ipsum").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("Small-batch, whatever.").font(.system(size: 10)).foregroundStyle(secondary)
            }.offset(x: 152, y: 117)
            Text("Artisan cloud bread,\nkinfolk echo park.")
                .font(.system(size: 15)).lineSpacing(5)
                .foregroundStyle(secondary).offset(x: 84, y: 187)
            tile(symbol: "square.stack.3d.up", color: Color(red: 0.65, green: 0.57, blue: 0.94))
                .offset(x: 84, y: 254)
            tile(symbol: "circle.lefthalf.filled", color: Color(red: 0.42, green: 0.77, blue: 0.75))
                .offset(x: 216, y: 254)
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.49, green: 0.78, blue: 0.96))
                .overlay {
                    HStack(spacing: 35) {
                        Text("Whatever").font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .medium))
                    }.foregroundStyle(Color(red: 0.06, green: 0.16, blue: 0.24))
                }.frame(width: 248, height: 44).offset(x: 84, y: 350)
            Canvas { context, _ in
                func line(_ a: CGPoint, _ b: CGPoint, color: Color, dashed: Bool = false) {
                    var path = Path(); path.move(to: a); path.addLine(to: b)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : []))
                }
                func label(_ text: String, at point: CGPoint, color: Color) {
                    let resolved = context.resolve(Text(text).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(color))
                    let size = resolved.measure(in: CGSize(width: 360, height: 30))
                    let rect = CGRect(x: point.x - size.width / 2 - 8, y: point.y - 12, width: size.width + 16, height: 24)
                    context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color(red: 0.065, green: 0.085, blue: 0.12)))
                    context.draw(resolved, at: point, anchor: .center)
                }
                func dimension(_ a: CGPoint, _ b: CGPoint, text: String, at point: CGPoint, color: Color) {
                    line(a, b, color: color)
                    let horizontal = a.y == b.y
                    for p in [a, b] {
                        line(CGPoint(x: p.x - (horizontal ? 0 : 4), y: p.y - (horizontal ? 4 : 0)),
                             CGPoint(x: p.x + (horizontal ? 0 : 4), y: p.y + (horizontal ? 4 : 0)), color: color)
                    }
                    label(text, at: point, color: color)
                }
                if state.phase >= 1 {
                    let color = state.phase >= 2 ? orange : cyan
                    dimension(CGPoint(x: 200, y: 286), CGPoint(x: 216, y: 286), text: "16 px", at: CGPoint(x: 208, y: 334), color: color)
                    if state.phase == 1 {
                        dimension(CGPoint(x: 352, y: 254), CGPoint(x: 352, y: 318), text: "64 px", at: CGPoint(x: 382, y: 286), color: cyan)
                    }
                }
                if state.phase >= 3 {
                    let p = state.progress
                    let rect = CGRect(x: 84, y: 350, width: 248 * p, height: 44 * p)
                    let color = state.phase >= 4 ? orange : cyan
                    context.fill(Path(rect), with: .color(color.opacity(0.07)))
                    context.stroke(Path(rect), with: .color(color), style: StrokeStyle(lineWidth: 1, dash: state.phase >= 4 ? [4, 3] : []))
                    if state.phase == 3 {
                        for point in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)] {
                            context.fill(Path(CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(color))
                        }
                    }
                    let text = state.phase >= 4 ? "1 · 248 × 44 px" : "\(Int((248 * p).rounded())) × \(Int((44 * p).rounded())) px"
                    label(text, at: CGPoint(x: 208, y: 414), color: color)
                }
                if state.phase == 5 {
                    dimension(CGPoint(x: 128, y: 134), CGPoint(x: 152, y: 134), text: "24 px", at: CGPoint(x: 140, y: 100), color: cyan)
                    label("Copied  width: 248px; height: 44px;", at: CGPoint(x: 220, y: 478), color: .white.opacity(0.85))
                }
                let point: CGPoint = switch state.phase {
                case 0: CGPoint(x: 353, y: 220)
                case 1, 2: CGPoint(x: 208, y: 286)
                case 3: CGPoint(x: 84 + 248 * state.progress, y: 350 + 44 * state.progress)
                case 4: CGPoint(x: 342, y: 405)
                default: CGPoint(x: 140, y: 134)
                }
                if state.phase == 3 {
                    line(CGPoint(x: point.x - 6, y: point.y), CGPoint(x: point.x + 6, y: point.y), color: .white)
                    line(CGPoint(x: point.x, y: point.y - 6), CGPoint(x: point.x, y: point.y + 6), color: .white)
                } else {
                    var pointer = Path()
                    pointer.move(to: point); pointer.addLine(to: CGPoint(x: point.x + 2, y: point.y + 17))
                    pointer.addLine(to: CGPoint(x: point.x + 6, y: point.y + 12)); pointer.addLine(to: CGPoint(x: point.x + 11, y: point.y + 18))
                    pointer.addLine(to: CGPoint(x: point.x + 14, y: point.y + 16)); pointer.addLine(to: CGPoint(x: point.x + 9, y: point.y + 10))
                    pointer.addLine(to: CGPoint(x: point.x + 16, y: point.y + 9)); pointer.closeSubpath()
                    context.fill(pointer, with: .color(.black.opacity(0.9)))
                    context.stroke(pointer, with: .color(.white), lineWidth: 1.2)
                }
            }
        }.frame(width: 440, height: 520)
    }

    private func tile(symbol: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.15, green: 0.18, blue: 0.25))
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color)
                }.padding(.leading, 12)
            }.frame(width: 116, height: 64)
    }
}

var frames: [(DemoState, Int)] = [(.init(phase: 0), 700), (.init(phase: 1), 1500), (.init(phase: 2), 750)]
for step in 1...12 { frames.append((.init(phase: 3, progress: CGFloat(step) / 12), 65)) }
frames += [(.init(phase: 3), 700), (.init(phase: 4), 1000), (.init(phase: 5), 2200), (.init(phase: 0), 450)]

try MainActor.assumeIsolated {
    @MainActor func render(_ state: DemoState, to url: URL) throws {
        let renderer = ImageRenderer(content: IllustratedDemo(state: state))
        renderer.scale = 2
        guard let image = renderer.cgImage else { fatalError("Demo render failed") }
        precondition(image.width == 880 && image.height == 1040)
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        try png.write(to: url)
    }
    var arguments = ["img2webp", "-min_size", "-mixed", "-loop", "0", "-q", "92", "-m", "6"]
    for (index, frame) in frames.enumerated() {
        let path = staging.appendingPathComponent(String(format: "%02d.png", index))
        try render(frame.0, to: path)
        arguments += ["-d", String(frame.1), path.path]
    }
    let poster = root.appendingPathComponent("Assets/Previews/Schnaps-Layout-Demo.png")
    try render(.init(phase: 5), to: poster)
    @discardableResult func run(_ arguments: [String]) throws -> Int32 {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments; try process.run(); process.waitUntilExit()
        precondition(process.terminationStatus == 0, "WebP export failed")
        return process.terminationStatus
    }
    try run(arguments + ["-o", assets.appendingPathComponent("schnaps-layout-demo.webp").path])
    try run(["cwebp", "-quiet", "-lossless", "-q", "75", "-m", "6", poster.path,
             "-o", assets.appendingPathComponent("schnaps-layout-demo-poster.webp").path])
    print("Illustrated demo: 880 × 1040, \(frames.reduce(0) { $0 + $1.1 }) ms, transparent background")
}
