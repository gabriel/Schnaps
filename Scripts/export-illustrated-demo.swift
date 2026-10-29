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
    private let coral = Color(red: 0.86, green: 0.34, blue: 0.24)
    private let ink = Color(red: 0.07, green: 0.07, blue: 0.075)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(red: 0.985, green: 0.98, blue: 0.955))
                .shadow(color: .black.opacity(0.09), radius: 10, y: 5)
                .frame(width: 356, height: 444).offset(x: 42, y: 36)
            Canvas { context, _ in
                var rules = Path()
                for y in stride(from: 104, through: 440, by: 48) {
                    rules.move(to: CGPoint(x: 58, y: y)); rules.addLine(to: CGPoint(x: 382, y: y))
                }
                for x in [58, 374] {
                    rules.move(to: CGPoint(x: x, y: 26)); rules.addLine(to: CGPoint(x: x, y: 490))
                }
                context.stroke(rules, with: .color(.black.opacity(0.075)), lineWidth: 0.8)
            }
            Rectangle().fill(ink).frame(width: 175, height: 7).offset(x: 58, y: 36)
            Rectangle().fill(Color(red: 0.84, green: 0.40, blue: 0.72)).frame(width: 158, height: 7).offset(x: 233, y: 36)
            Rectangle().fill(Color(red: 1, green: 0.87, blue: 0.04)).frame(width: 17, height: 302).offset(x: 374, y: 82)
            Text("fig. 6").font(.custom("SignPainter-HouseScript", size: 122)).foregroundStyle(ink)
                .frame(width: 252, height: 160).rotationEffect(.degrees(-4)).offset(x: 91, y: 202)
            Text("Artisan cloud bread.\nFixie, whatever.")
                .font(.custom("Noteworthy-Light", size: 12)).lineSpacing(2)
                .foregroundStyle(ink.opacity(0.5)).offset(x: 81, y: 405)
            Canvas { context, _ in
                func stroke(_ path: Path, opacity: Double = 1, dashed: Bool = false) {
                    context.stroke(path, with: .color(coral.opacity(opacity)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round, dash: dashed ? [3, 5] : []))
                }
                func note(_ text: String, at point: CGPoint, size: CGFloat = 15, color: Color? = nil) {
                    context.draw(Text(text).font(.custom("Noteworthy-Light", size: size)).foregroundStyle(color ?? coral), at: point)
                }
                func arrow(_ a: CGPoint, _ b: CGPoint, bend: CGFloat = 2) {
                    var path = Path(); path.move(to: a)
                    let horizontal = a.y == b.y
                    path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + (horizontal ? 0 : bend), y: (a.y + b.y) / 2 + (horizontal ? bend : 0)))
                    if horizontal {
                        path.move(to: CGPoint(x: a.x + 5, y: a.y - 3)); path.addLine(to: a); path.addLine(to: CGPoint(x: a.x + 5, y: a.y + 3))
                        path.move(to: CGPoint(x: b.x - 5, y: b.y - 3)); path.addLine(to: b); path.addLine(to: CGPoint(x: b.x - 5, y: b.y + 3))
                    } else {
                        path.move(to: CGPoint(x: a.x - 3, y: a.y + 5)); path.addLine(to: a); path.addLine(to: CGPoint(x: a.x + 3, y: a.y + 5))
                        path.move(to: CGPoint(x: b.x - 3, y: b.y - 5)); path.addLine(to: b); path.addLine(to: CGPoint(x: b.x + 3, y: b.y - 5))
                    }
                    stroke(path)
                }
                if state.phase >= 1 {
                    arrow(CGPoint(x: 98, y: 184), CGPoint(x: 338, y: 184), bend: 5)
                    note("240 × 150", at: CGPoint(x: 217, y: 167))
                    arrow(CGPoint(x: 78, y: 75), CGPoint(x: 78, y: 176), bend: -3)
                    note("margin-top 101", at: CGPoint(x: 145, y: 127), size: 13)
                }
                if state.phase >= 2 {
                    arrow(CGPoint(x: 298, y: 89), CGPoint(x: 366, y: 89), bend: -2)
                    note("68 pt", at: CGPoint(x: 276, y: 87), size: 13)
                }
                if state.phase >= 3 {
                    let rect = CGRect(x: 98, y: 204, width: 240 * state.progress, height: 150 * state.progress)
                    context.fill(Path(rect), with: .color(coral.opacity(0.025)))
                    stroke(Path(rect), opacity: 0.7, dashed: state.phase >= 4)
                    if state.phase == 3 {
                        for point in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)] {
                            context.fill(Path(CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(coral))
                        }
                    }
                    note(state.phase >= 4 ? "1 · 240 × 150 pt" : "\(Int((240 * state.progress).rounded())) × \(Int((150 * state.progress).rounded())) pt", at: CGPoint(x: 218, y: 379), size: 14)
                }
                if state.phase == 5 {
                    note("width: 240px; height: 150px;", at: CGPoint(x: 239, y: 453), size: 11, color: ink.opacity(0.6))
                    var check = Path(); check.move(to: CGPoint(x: 99, y: 451)); check.addLine(to: CGPoint(x: 103, y: 455)); check.addLine(to: CGPoint(x: 111, y: 446)); stroke(check)
                }
                let point: CGPoint = switch state.phase {
                case 0: CGPoint(x: 348, y: 392)
                case 1: CGPoint(x: 217, y: 184)
                case 2: CGPoint(x: 342, y: 89)
                case 3: CGPoint(x: 98 + 240 * state.progress, y: 204 + 150 * state.progress)
                case 4: CGPoint(x: 348, y: 367)
                default: CGPoint(x: 345, y: 451)
                }
                if state.phase == 3 {
                    var crosshair = Path(); crosshair.move(to: CGPoint(x: point.x - 6, y: point.y)); crosshair.addLine(to: CGPoint(x: point.x + 6, y: point.y)); crosshair.move(to: CGPoint(x: point.x, y: point.y - 6)); crosshair.addLine(to: CGPoint(x: point.x, y: point.y + 6)); stroke(crosshair)
                } else if state.phase < 5 {
                    var pointer = Path(); pointer.move(to: point); pointer.addLine(to: CGPoint(x: point.x + 2, y: point.y + 14)); pointer.addLine(to: CGPoint(x: point.x + 6, y: point.y + 9)); pointer.addLine(to: CGPoint(x: point.x + 12, y: point.y + 8)); pointer.closeSubpath()
                    context.fill(pointer, with: .color(ink)); context.stroke(pointer, with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
            }
        }.frame(width: 440, height: 520)
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
