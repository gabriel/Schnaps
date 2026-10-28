#!/usr/bin/env swift
import Foundation

// Swift-only app packaging. macOS 26 + Xcode 26 compile the Icon Composer source;
// older hosts/toolchains use the checked-in ICNS exported by the same Apple compiler.
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
let architectureFlags = CommandLine.arguments.contains("--universal") ? ["--arch", "arm64", "--arch", "x86_64"] : []
_ = try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration] + architectureFlags)
let binPath = try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration] + architectureFlags + ["--show-bin-path"], capture: true)
let release = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Config/Release.json"))) as! [String: String]
let app = root.appendingPathComponent("build/Schnaps.app")
let contents = app.appendingPathComponent("Contents")
let resources = contents.appendingPathComponent("Resources")
try manager.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
let binary = contents.appendingPathComponent("MacOS/Schnaps")
if manager.fileExists(atPath: binary.path) { try manager.removeItem(at: binary) }
try manager.copyItem(at: URL(fileURLWithPath: binPath).appendingPathComponent("Schnaps"), to: binary)

let sdk = try run("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-version"], capture: true)
let sdkMajor = Int(sdk.split(separator: ".").first ?? "0") ?? 0
let hostMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
let modernIcon = sdkMajor >= 26 && hostMajor >= 26 && !CommandLine.arguments.contains("--legacy-icon")
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
    "CFBundleShortVersionString": release["version"]!, "CFBundleVersion": release["build"]!,
    "SUFeedURL": release["feedURL"]!, "SUPublicEDKey": release["publicEDKey"]!,
    "SUVerifyUpdateBeforeExtraction": true, "SURequireSignedFeed": true,
    "CFBundleIconFile": "Schnaps", "LSMinimumSystemVersion": "14.0",
    "LSUIElement": true, "NSHighResolutionCapable": true,
    "NSScreenCaptureUsageDescription": "Schnaps uses a still image of your displays to detect edges and measure screen elements. Images remain in memory on your Mac."
]
if modernIcon { info["CFBundleIconName"] = "Schnaps" }
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    .write(to: contents.appendingPathComponent("Info.plist"))
let framework = contents.appendingPathComponent("Frameworks/Sparkle.framework")
try manager.createDirectory(at: framework.deletingLastPathComponent(), withIntermediateDirectories: true)
if manager.fileExists(atPath: framework.path) { try manager.removeItem(at: framework) }
_ = try run("/usr/bin/ditto", [root.appendingPathComponent(".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework").path, framework.path])
let acknowledgements = resources.appendingPathComponent("Acknowledgements")
try manager.createDirectory(at: acknowledgements, withIntermediateDirectories: true)
let sparkleLicense = acknowledgements.appendingPathComponent("Sparkle-LICENSE.txt")
if manager.fileExists(atPath: sparkleLicense.path) { try manager.removeItem(at: sparkleLicense) }
try manager.copyItem(at: root.appendingPathComponent(".build/checkouts/Sparkle/LICENSE"), to: sparkleLicense)
let identity = ProcessInfo.processInfo.environment["SCHNAPS_SIGN_IDENTITY"]
    ?? ProcessInfo.processInfo.environment["SCHNAP_SIGN_IDENTITY"] ?? "-"
let distribution = identity.hasPrefix("Developer ID Application:")
let signingOptions = distribution ? ["--timestamp", "--options", "runtime"] : ["--timestamp=none"]
func sign(_ path: URL) throws {
    _ = try run("/usr/bin/codesign", ["--force", "--sign", identity] + signingOptions + [path.path])
}
// Sign nested code from the inside out; never rely on --deep to produce a release signature.
let version = framework.appendingPathComponent("Versions/B")
try sign(version.appendingPathComponent("Autoupdate"))
try sign(version.appendingPathComponent("Updater.app"))
let xpcServices = version.appendingPathComponent("XPCServices")
for service in try manager.contentsOfDirectory(at: xpcServices, includingPropertiesForKeys: nil) where service.pathExtension == "xpc" {
    try sign(service)
}
try sign(framework)
try sign(app)
_ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
print("Built \(app.path) (\(modernIcon ? "Icon Composer" : "legacy ICNS") icon)")
