#!/usr/bin/env swift
import Foundation

// Swift-only app packaging. Xcode 26 compiles the editable Icon Composer source;
// older toolchains use the checked-in ICNS exported by the same Apple compiler.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let configuration = CommandLine.arguments.contains("--debug") ? "debug" : "release"
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
_ = try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration])
let app = root.appendingPathComponent("build/Schnaps.app")
let contents = app.appendingPathComponent("Contents")
let resources = contents.appendingPathComponent("Resources")
try manager.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
let binary = contents.appendingPathComponent("MacOS/Schnaps")
if manager.fileExists(atPath: binary.path) { try manager.removeItem(at: binary) }
try manager.copyItem(at: root.appendingPathComponent(".build/\(configuration)/Schnaps"), to: binary)

let sdk = try run("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-version"], capture: true)
let sdkMajor = Int(sdk.split(separator: ".").first ?? "0") ?? 0
let modernIcon = sdkMajor >= 26 && !CommandLine.arguments.contains("--legacy-icon")
if modernIcon {
    _ = try run("/usr/bin/xcrun", ["actool", root.appendingPathComponent("Assets/Schnaps.icon").path,
        "--compile", resources.path, "--platform", "macosx", "--minimum-deployment-target", "14.0",
        "--app-icon", "Schnaps", "--output-partial-info-plist", root.appendingPathComponent("build/IconInfo.plist").path,
        "--output-format", "human-readable-text"])
} else {
    let car = resources.appendingPathComponent("Assets.car")
    if manager.fileExists(atPath: car.path) { try manager.removeItem(at: car) }
}
// actool emits only a small fallback ICNS. Supply all legacy sizes through 1024px.
let icon = resources.appendingPathComponent("Schnaps.icns")
if manager.fileExists(atPath: icon.path) { try manager.removeItem(at: icon) }
try manager.copyItem(at: root.appendingPathComponent("Assets/Compiled/Schnaps.icns"), to: icon)
var info: [String: Any] = [
    // Preserve the original identity so settings and capture authorization survive the rename.
    "CFBundleIdentifier": "com.gabrielhandford.Schnap",
    "CFBundleName": "Schnaps", "CFBundleDisplayName": "Schnaps",
    "CFBundleExecutable": "Schnaps", "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "2",
    "CFBundleIconFile": "Schnaps", "LSMinimumSystemVersion": "14.0",
    "LSUIElement": true, "NSHighResolutionCapable": true,
    "NSScreenCaptureUsageDescription": "Schnaps uses a still image of your displays to detect edges and measure screen elements. Images remain in memory on your Mac."
]
if modernIcon { info["CFBundleIconName"] = "Schnaps" }
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    .write(to: contents.appendingPathComponent("Info.plist"))
let identity = ProcessInfo.processInfo.environment["SCHNAPS_SIGN_IDENTITY"]
    ?? ProcessInfo.processInfo.environment["SCHNAP_SIGN_IDENTITY"] ?? "-"
_ = try run("/usr/bin/codesign", ["--force", "--sign", identity, "--timestamp=none", app.path])
print("Built \(app.path) (\(modernIcon ? "Icon Composer" : "legacy ICNS") icon)")
