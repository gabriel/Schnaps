#!/usr/bin/env swift
import Foundation
import FoundationXML

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manager = FileManager.default
let environment = ProcessInfo.processInfo.environment
let config = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Config/Release.json"))) as! [String: String]
guard environment["SCHNAPS_SIGN_IDENTITY"]?.hasPrefix("Developer ID Application:") == true else {
    fatalError("Set SCHNAPS_SIGN_IDENTITY to your Developer ID Application signing identity.")
}
let profile = environment["SCHNAPS_NOTARY_PROFILE"] ?? "Schnaps"
let version = config["version"]!, account = config["keychainAccount"]!
let output = root.appendingPathComponent("build/releases/\(version)")
try manager.createDirectory(at: output, withIntermediateDirectories: true)
@discardableResult
func run(_ executable: String, _ arguments: [String], capture: Bool = false, directory: URL? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = directory ?? root
    let pipe = Pipe()
    if capture { process.standardOutput = pipe }
    try process.run()
    let data = capture ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: executable, code: Int(process.terminationStatus)) }
    return String(decoding: data, as: UTF8.self)
}
func notarize(_ file: URL) throws {
    let response = try run("/usr/bin/xcrun", ["notarytool", "submit", file.path, "--keychain-profile", profile, "--wait", "--output-format", "json"], capture: true)
    let result = try JSONSerialization.jsonObject(with: Data(response.utf8)) as! [String: Any]
    try Data(response.utf8).write(to: output.appendingPathComponent(file.lastPathComponent + ".notary.json"))
    guard result["status"] as? String == "Accepted" else {
        throw NSError(domain: "Notarization rejected: \(result["id"] ?? "unknown") — inspect the saved report", code: 1)
    }
    print("Notarization accepted: \(file.lastPathComponent)")
}
try run("/usr/bin/xcrun", ["swift", "Scripts/build-app.swift", "--universal"])
let app = root.appendingPathComponent("build/Schnaps.app")
let zip = output.appendingPathComponent("Schnaps-notarization.zip")
try run("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path])
try notarize(zip)
try run("/usr/bin/xcrun", ["stapler", "staple", app.path])
try run("/usr/bin/xcrun", ["stapler", "validate", app.path])
try run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=2", app.path])
let staging = root.appendingPathComponent("build/DMG-Staging")
if manager.fileExists(atPath: staging.path) { try manager.removeItem(at: staging) }
try manager.createDirectory(at: staging, withIntermediateDirectories: true)
try run("/usr/bin/ditto", [app.path, staging.appendingPathComponent("Schnaps.app").path])
try manager.createSymbolicLink(atPath: staging.appendingPathComponent("Applications").path, withDestinationPath: "/Applications")
let dmg = output.appendingPathComponent("Schnaps-\(version).dmg")
try run("/usr/bin/hdiutil", ["create", "-volname", "Schnaps \(version)", "-srcfolder", staging.path, "-format", "UDZO", "-ov", dmg.path])
try run("/usr/bin/codesign", ["--force", "--sign", environment["SCHNAPS_SIGN_IDENTITY"]!, "--timestamp", dmg.path])
try notarize(dmg)
try run("/usr/bin/xcrun", ["stapler", "staple", dmg.path])
try run("/usr/bin/xcrun", ["stapler", "validate", dmg.path])
try run("/usr/bin/hdiutil", ["verify", dmg.path])
// Do not let generate_appcast discover the intermediate ZIP as a second update.
try manager.removeItem(at: zip)
let notes = root.appendingPathComponent("releases/\(version).md")
if manager.fileExists(atPath: notes.path) {
    let destination = output.appendingPathComponent("Schnaps-\(version).md")
    if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
    try manager.copyItem(at: notes, to: destination)
}
let tools = root.appendingPathComponent(".build/artifacts/sparkle/Sparkle/bin")
try run(tools.appendingPathComponent("generate_appcast").path,
        ["--account", account, "--download-url-prefix", "https://github.com/\(config["repository"]!)/releases/download/v\(version)/", "--embed-release-notes", output.path])
let appcast = output.appendingPathComponent("appcast.xml")
try run(tools.appendingPathComponent("sign_update").path, ["--account", account, "--verify", appcast.path])
let xml = try XMLDocument(contentsOf: appcast)
let enclosure = try xml.nodes(forXPath: "//enclosure").first as! XMLElement
let signature = enclosure.attribute(forName: "sparkle:edSignature")!.stringValue!
try run(tools.appendingPathComponent("sign_update").path, ["--account", account, "--verify", dmg.path, signature])
let alias = output.appendingPathComponent("Schnaps.dmg")
if manager.fileExists(atPath: alias.path) { try manager.removeItem(at: alias) }
try manager.copyItem(at: dmg, to: alias)
let checksums = try run("/usr/bin/shasum", ["-a", "256", dmg.lastPathComponent, alias.lastPathComponent], capture: true, directory: output)
try Data(checksums.utf8).write(to: output.appendingPathComponent("SHA256SUMS"))
print("Ready to publish: \(output.path)")
