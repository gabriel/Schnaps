#!/usr/bin/env swift
import AppKit
import Foundation

// Swift-only app packaging with transparent liquid-glass branding.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let installDebug = CommandLine.arguments.contains("--install-debug")
let configuration = CommandLine.arguments.contains("--debug") || installDebug ? "debug" : "release"
let isDebug = configuration == "debug"
let appName = isDebug ? "SchnapsDebug" : "Schnaps"
let bundleIdentifier = "com.gabrielhandford.Schnap" + (isDebug ? ".debug" : "")
let manager = FileManager.default
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}
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
// Privacy grants follow the signing identity, not just the installation path.
// Select an unambiguous development certificate for debug builds, including worktrees.
let configuredIdentity = ProcessInfo.processInfo.environment["SCHNAPS_SIGN_IDENTITY"]
    ?? ProcessInfo.processInfo.environment["SCHNAP_SIGN_IDENTITY"]
var identity = configuredIdentity ?? "-"
if isDebug && configuredIdentity == nil {
    let identities = try run("/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"], capture: true)
    let developmentIdentities = identities.split(separator: "\n").filter { $0.contains("\"Apple Development:") }
    if developmentIdentities.count == 1 {
        identity = String(developmentIdentities[0].split(whereSeparator: \.isWhitespace)[1])
    }
}
if installDebug && identity == "-" {
    fail("Installing SchnapsDebug requires stable signing. Set SCHNAPS_SIGN_IDENTITY to an installed Apple Development identity (automatically selected when exactly one is available).")
}
let architectureFlags = CommandLine.arguments.contains("--universal") ? ["--arch", "arm64", "--arch", "x86_64"] : []
_ = try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration] + architectureFlags)
let binPath = try run("/usr/bin/xcrun", ["swift", "build", "-c", configuration] + architectureFlags + ["--show-bin-path"], capture: true)
let release = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: ProcessInfo.processInfo.environment["SCHNAPS_RELEASE_CONFIG"] ?? root.appendingPathComponent("Config/Release.json").path))) as! [String: String]
let app = root.appendingPathComponent("build/\(appName).app")
let contents = app.appendingPathComponent("Contents")
let resources = contents.appendingPathComponent("Resources")
try manager.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
let proCatalog = resources.appendingPathComponent("Pro.json")
if manager.fileExists(atPath: proCatalog.path) { try manager.removeItem(at: proCatalog) }
try manager.copyItem(at: root.appendingPathComponent("Config/Pro.json"), to: proCatalog)
let binary = contents.appendingPathComponent("MacOS/Schnaps")
if manager.fileExists(atPath: binary.path) { try manager.removeItem(at: binary) }
try manager.copyItem(at: URL(fileURLWithPath: binPath).appendingPathComponent("Schnaps"), to: binary)

// Modern macOS selects Icon Composer appearances; older macOS uses transparent ICNS variants.
let car = resources.appendingPathComponent("Assets.car")
if manager.fileExists(atPath: car.path) { try manager.removeItem(at: car) }
try manager.copyItem(at: root.appendingPathComponent("Assets/Compiled/Assets.car"), to: car)
for name in ["Schnaps", "Schnaps-Dark", "Schnaps-Mark", "Schnaps-Mark-Dark"] {
    let icon = resources.appendingPathComponent("\(name).icns")
    if manager.fileExists(atPath: icon.path) { try manager.removeItem(at: icon) }
    try manager.copyItem(at: root.appendingPathComponent("Assets/Compiled/\(name).icns"), to: icon)
}
var info: [String: Any] = [
    // Release keeps its original identity; debug has separate settings and privacy grants.
    "CFBundleIdentifier": bundleIdentifier,
    "CFBundleName": appName, "CFBundleDisplayName": appName,
    "CFBundleExecutable": "Schnaps", "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": release["version"]!, "CFBundleVersion": release["build"]!,
    "SchnapsBuildConfiguration": configuration,
    "SchnapsUpdateChannel": release["defaultChannel"] ?? "stable",
    "CFBundleIconFile": "Schnaps", "CFBundleIconName": "Schnaps", "LSMinimumSystemVersion": "14.0",
    "LSUIElement": true, "NSHighResolutionCapable": true,
    "NSScreenCaptureUsageDescription": "Schnaps captures your displays to detect edges and measure screen elements. Images stay on your Mac unless you explicitly export or share them."
]
if !isDebug {
    info["SUFeedURL"] = release["feedURL"]!
    info["SUPublicEDKey"] = release["publicEDKey"]!
    info["SUVerifyUpdateBeforeExtraction"] = true
    info["SURequireSignedFeed"] = true
}
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    .write(to: contents.appendingPathComponent("Info.plist"))
let framework = contents.appendingPathComponent("Frameworks/Sparkle.framework")
try manager.createDirectory(at: framework.deletingLastPathComponent(), withIntermediateDirectories: true)
if manager.fileExists(atPath: framework.path) { try manager.removeItem(at: framework) }
_ = try run("/usr/bin/ditto", [root.appendingPathComponent(".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework").path, framework.path])
let fontDestination=resources.appendingPathComponent("FontAwesome.otf")
if manager.fileExists(atPath:fontDestination.path) { try manager.removeItem(at:fontDestination) }
try manager.copyItem(at:root.appendingPathComponent("Assets/Fonts/FontAwesome.otf"),to:fontDestination)
let acknowledgements = resources.appendingPathComponent("Acknowledgements")
try manager.createDirectory(at: acknowledgements, withIntermediateDirectories: true)
let sparkleLicense = acknowledgements.appendingPathComponent("Sparkle-LICENSE.txt")
if manager.fileExists(atPath: sparkleLicense.path) { try manager.removeItem(at: sparkleLicense) }
try manager.copyItem(at: root.appendingPathComponent(".build/checkouts/Sparkle/LICENSE"), to: sparkleLicense)
for source in try manager.contentsOfDirectory(at:root.appendingPathComponent("Assets/Licenses"),includingPropertiesForKeys:nil) where source.pathExtension == "txt" {
    let target=acknowledgements.appendingPathComponent(source.lastPathComponent)
    if manager.fileExists(atPath:target.path) { try manager.removeItem(at:target) }
    try manager.copyItem(at:source,to:target)
}
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
print("Built \(app.path) (transparent liquid-glass icon and brand mark)")

if installDebug {
    let destination = URL(fileURLWithPath: "/Applications/SchnapsDebug.app", isDirectory: true)
    // Refuse to replace an unrelated app at this path.
    if manager.fileExists(atPath: destination.path) {
        guard Bundle(url: destination)?.bundleIdentifier == bundleIdentifier else {
            fail("Refusing to replace an unrelated app at \(destination.path)")
        }
    }
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    for application in running where !application.terminate() {
        fail("Quit SchnapsDebug before installing the new build.")
    }
    let deadline = Date().addingTimeInterval(5)
    while running.contains(where: { !$0.isTerminated }), Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    guard running.allSatisfy({ $0.isTerminated }) else {
        fail("SchnapsDebug is still running. Quit it before installing the new build.")
    }
    let staged = destination.deletingLastPathComponent().appendingPathComponent(".SchnapsDebug-\(UUID().uuidString).app")
    defer { try? manager.removeItem(at: staged) }
    try manager.copyItem(at: app, to: staged)
    if manager.fileExists(atPath: destination.path) {
        _ = try manager.replaceItemAt(destination, withItemAt: staged)
    } else {
        try manager.moveItem(at: staged, to: destination)
    }
    _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", destination.path])
    print("Installed \(destination.path). Enable its permissions once in System Settings.")
}
