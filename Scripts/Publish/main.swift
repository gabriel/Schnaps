import Darwin
import Foundation

struct PublishError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
struct Runner {
    let root: URL
    var environment = ProcessInfo.processInfo.environment
    @discardableResult func run(_ args: [String], capture: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = root
        process.environment = environment
        let pipe = Pipe()
        if capture { process.standardOutput = pipe }
        try process.run()
        let data = capture ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PublishError("\(args.first ?? "Command") failed (\(process.terminationStatus)).")
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
struct GitHubRelease: Decodable {
    let tagName: String
    let isDraft: Bool
    let isPrerelease: Bool
}
struct Manifest: Codable {
    let version: String
    let build: Int
    let channel: String
    let revision: String
}

@main struct Publisher {
    static func main() {
        do { try publish() } catch {
            FileHandle.standardError.write(Data("Release failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    static func publish() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let first = args.first, let channel = UpdateChannel(rawValue: first) else {
            throw PublishError(
                "Use make beta or make release. Optional ARGS: --plan, --version X.Y.Z, --resume VERSION.")
        }
        var index = 1
        var seen = Set<String>()
        while index < args.count {
            let argument = args[index]
            guard ["--plan", "--version", "--resume"].contains(argument), seen.insert(argument).inserted else {
                throw PublishError("Unknown or repeated option: \(argument)")
            }
            index += argument == "--plan" ? 1 : 2
        }
        guard !(seen.contains("--version") && seen.contains("--resume")) else {
            throw PublishError("Use --version or --resume, not both.")
        }
        func option(_ name: String) throws -> String? {
            guard let index = args.firstIndex(of: name) else { return nil }
            guard args.indices.contains(index + 1), !args[index + 1].hasPrefix("--") else {
                throw PublishError("Missing value for \(name).")
            }
            return args[index + 1]
        }
        let planOnly = args.contains("--plan")
        let requested = try option("--version")
        let resume = try option("--resume")
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let manager = FileManager.default
        var runner = Runner(root: root)
        var config = try JSONDecoder().decode(
            [String: String].self, from: Data(contentsOf: root.appendingPathComponent("Config/Release.json")))
        guard let repository = config["repository"], repository == "gabriel/Schnaps",
            let account = config["keychainAccount"],
            let configuredVersion = config["version"], let configuredBuild = Int(config["build"] ?? "")
        else { throw PublishError("Invalid release configuration.") }
        let revision = try runner.run(["git", "rev-parse", "HEAD"], capture: true)
        if !planOnly {
            guard try runner.run(["git", "status", "--porcelain"], capture: true).isEmpty else {
                throw PublishError("Commit or stash changes before publishing.")
            }
            let branch = try runner.run(["git", "branch", "--show-current"], capture: true)
            if channel == .stable && branch != "main" {
                throw PublishError("Publish stable releases from main; beta releases may use a pushed feature branch.")
            }
            guard !branch.isEmpty,
                try runner.run(["git", "ls-remote", "origin", "refs/heads/\(branch)"], capture: true).hasPrefix(
                    revision)
            else {
                throw PublishError("Push the current branch before publishing its commit.")
            }
        }
        let lock = root.appendingPathComponent("build/Publish.lock")
        try manager.createDirectory(at: lock.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard mkdir(lock.path, 0o700) == 0 else {
            throw PublishError(
                "Another publisher is running (build/Publish.lock). Remove a stale lock only after its process has stopped."
            )
        }
        defer { try? manager.removeItem(at: lock) }
        let temporary = root.appendingPathComponent("build/Publish-\(UUID().uuidString)")
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let tools = root.appendingPathComponent(".build/artifacts/sparkle/Sparkle/bin")
        if !manager.fileExists(atPath: tools.path) { try runner.run(["swift", "package", "resolve"]) }
        func releases() throws -> [GitHubRelease] {
            let json = try runner.run(
                [
                    "gh", "release", "list", "--repo", repository, "--limit", "100", "--json",
                    "tagName,isDraft,isPrerelease",
                ], capture: true)
            return try JSONDecoder().decode([GitHubRelease].self, from: Data(json.utf8))
        }
        func downloadFeed(tag: String) throws -> Data {
            let directory = temporary.appendingPathComponent(UUID().uuidString)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try runner.run([
                "gh", "release", "download", tag, "--repo", repository, "--pattern", "appcast.xml", "--dir",
                directory.path,
            ])
            let path = directory.appendingPathComponent("appcast.xml")
            try runner.run([
                tools.appendingPathComponent("sign_update").path, "--account", account, "--verify", path.path,
            ])
            let data = try Data(contentsOf: path)
            _ = try ReleaseFeed.entries(data)
            return data
        }
        func seedFeeds(_ available: [GitHubRelease], includeDrafts: Bool = false) throws -> [Data] {
            var feeds: [Data] = []
            let versioned = available.filter { (includeDrafts || !$0.isDraft) && $0.tagName.hasPrefix("v") }
            func latest(_ beta: Bool) -> GitHubRelease? {
                versioned.filter { $0.isPrerelease == beta }.max {
                    (ReleaseVersion(String($0.tagName.dropFirst())) ?? ReleaseVersion("0.0.0")!)
                        < (ReleaseVersion(String($1.tagName.dropFirst())) ?? ReleaseVersion("0.0.0")!)
                }
            }
            // Individual release feeds recover build allocation if a prior feed upload failed.
            for release in [latest(false), latest(true)].compactMap({ $0 }) {
                feeds.append(try downloadFeed(tag: release.tagName))
            }
            if available.contains(where: { $0.tagName == "updates" && !$0.isDraft }) {
                feeds.append(try downloadFeed(tag: "updates"))
            }
            return feeds
        }
        let available = try releases()
        let initialFeeds = try seedFeeds(available, includeDrafts: true)
        let known = available.filter { $0.tagName.hasPrefix("v") }.map { String($0.tagName.dropFirst()) }
        let manifest: Manifest
        if let resume {
            guard ReleaseVersion(resume) != nil else { throw PublishError("Invalid resume version.") }
            manifest = try JSONDecoder().decode(
                Manifest.self,
                from: Data(contentsOf: root.appendingPathComponent("build/releases/\(resume)/release-manifest.json")))
            guard manifest.version == resume, manifest.revision == revision, manifest.channel == channel.rawValue else {
                throw PublishError("Resume must use the original commit and channel.")
            }
        } else {
            let version: ReleaseVersion
            if channel == .beta {
                version = try ReleasePlanning.nextBeta(
                    configured: configuredVersion, known: known, requested: requested)
            } else {
                guard let stable = ReleaseVersion(requested ?? configuredVersion), stable.beta == nil,
                    !known.compactMap(ReleaseVersion.init).filter({ $0.beta == nil }).contains(where: { $0 >= stable })
                else {
                    throw PublishError("Increase the stable version in Config/Release.json or use --version X.Y.Z.")
                }
                version = stable
            }
            let builds = try initialFeeds.flatMap { try ReleaseFeed.entries($0).map(\.build) }
            manifest = Manifest(
                version: version.string,
                build: try ReleasePlanning.nextBuild(configured: configuredBuild, published: builds),
                channel: channel.rawValue, revision: revision)
        }
        let output = root.appendingPathComponent("build/releases/\(manifest.version)")
        let tag = "v\(manifest.version)"
        print("\(channel.title): \(manifest.version) (\(manifest.build)) from \(revision.prefix(12))")
        if planOnly { return }
        config["version"] = manifest.version
        config["build"] = String(manifest.build)
        config["defaultChannel"] = channel.rawValue
        let existing = available.first { $0.tagName == tag }
        guard existing == nil || resume != nil else {
            throw PublishError("Release \(tag) already exists; use --resume \(manifest.version).")
        }
        let ready = output.appendingPathComponent("packaged.txt")
        if !manager.fileExists(atPath: ready.path) {
            guard existing == nil else {
                throw PublishError(
                    "Cannot rebuild files already uploaded to a release. Restore the original packaged artifacts before resuming."
                )
            }
            if manager.fileExists(atPath: output.path) { try manager.removeItem(at: output) }
            try manager.createDirectory(at: output, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: output.appendingPathComponent("release-manifest.json"))
        let configURL = output.appendingPathComponent("Release.json")
        try encoder.encode(config).write(to: configURL)
        runner.environment["SCHNAPS_RELEASE_CONFIG"] = configURL.path
        if runner.environment["SCHNAPS_SIGN_IDENTITY"] == nil {
            let identities = try runner.run(["security", "find-identity", "-v", "-p", "codesigning"], capture: true)
                .split(separator: "\n").compactMap { line -> String? in
                    let quoted = line.split(separator: "\"")
                    return quoted.count > 1 && quoted[1].hasPrefix("Developer ID Application:")
                        ? String(quoted[1]) : nil
                }
            guard identities.count == 1 else {
                throw PublishError("Set SCHNAPS_SIGN_IDENTITY to the intended Developer ID Application identity.")
            }
            runner.environment["SCHNAPS_SIGN_IDENTITY"] = identities[0]
        }
        if !manager.fileExists(atPath: ready.path) {
            let profile = runner.environment["SCHNAPS_NOTARY_PROFILE"] ?? "Schnaps"
            do {
                _ = try runner.run(
                    ["xcrun", "notarytool", "history", "--keychain-profile", profile, "--output-format", "json"],
                    capture: true)
            } catch {
                throw PublishError(
                    "Notarization profile '\(profile)' is unavailable. Set SCHNAPS_NOTARY_PROFILE to an existing notarytool Keychain profile before publishing."
                )
            }
            try runner.run(["swift", "Scripts/release.swift"])
        }
        let dmg = output.appendingPathComponent("Schnaps-\(manifest.version).dmg")
        let appcast = output.appendingPathComponent("appcast.xml")
        try Runner(root: output, environment: runner.environment).run(["shasum", "-a", "256", "--check", "SHA256SUMS"])
        try runner.run(["codesign", "--verify", "--strict", dmg.path])
        try runner.run(["xcrun", "stapler", "validate", dmg.path])
        try runner.run([
            tools.appendingPathComponent("sign_update").path, "--account", account, "--verify", appcast.path,
        ])
        let entry = try ReleaseFeed.entries(Data(contentsOf: appcast)).first
        guard let entry, entry.version == manifest.version, entry.build == manifest.build, entry.channel == channel
        else { throw PublishError("Packaged appcast does not match the release plan.") }
        try runner.run([
            tools.appendingPathComponent("sign_update").path, "--account", account, "--verify", dmg.path,
            entry.signature,
        ])
        let notes = output.appendingPathComponent("release-notes.md")
        let authored = root.appendingPathComponent("releases/\(manifest.version).md")
        let noteText =
            manager.fileExists(atPath: authored.path)
            ? try String(contentsOf: authored, encoding: .utf8)
            : "Schnaps \(manifest.version)\n\n\(channel == .beta ? "Early build" : "Release") from commit \(revision).\n\nUniversal for Apple Silicon and Intel. Requires macOS 14 or later.\n"
        try Data(noteText.utf8).write(to: notes)
        let files = [
            dmg.path, output.appendingPathComponent("Schnaps.dmg").path, appcast.path,
            output.appendingPathComponent("SHA256SUMS").path,
            output.appendingPathComponent("release-manifest.json").path,
        ]
        if existing == nil {
            try runner.run(
                [
                    "gh", "release", "create", tag, "--repo", repository, "--draft", "--target", revision,
                    "--title", "Schnaps \(manifest.version)", "--notes-file", notes.path,
                ] + (channel == .beta ? ["--prerelease"] : []) + files)
        } else if existing?.isDraft == true {
            // Draft artifacts are not public. Published archives are never overwritten.
            try runner.run(["gh", "release", "upload", tag, "--repo", repository, "--clobber"] + files)
        } else {
            let downloaded = temporary.appendingPathComponent("published")
            try manager.createDirectory(at: downloaded, withIntermediateDirectories: true)
            try runner.run([
                "gh", "release", "download", tag, "--repo", repository, "--pattern", "release-manifest.json", "--dir",
                downloaded.path,
            ])
            let prior = try JSONDecoder().decode(
                Manifest.self, from: Data(contentsOf: downloaded.appendingPathComponent("release-manifest.json")))
            guard prior.revision == revision, prior.build == manifest.build, prior.channel == manifest.channel else {
                throw PublishError("Published release belongs to a different plan.")
            }
        }
        // Refresh immediately before publication; catch a build claimed by another publisher.
        let fresh = try releases()
        let feeds = try seedFeeds(fresh)
        let reservedFeeds = try seedFeeds(fresh, includeDrafts: true)
        let newer = try reservedFeeds.flatMap { try ReleaseFeed.entries($0) }.contains {
            $0.build >= manifest.build && $0.version != manifest.version
        }
        guard !newer else {
            throw PublishError(
                "Another release claimed this build or a newer build. Plan a new release before publishing.")
        }
        if existing == nil || existing?.isDraft == true {
            try runner.run([
                "gh", "release", "edit", tag, "--repo", repository, "--draft=false", "--prerelease=\(channel == .beta)",
                "--latest=\(channel == .stable)",
            ])
        }
        let combined = temporary.appendingPathComponent("appcast.xml")
        try ReleaseFeed.merge(feeds + [Data(contentsOf: appcast)]).write(to: combined)
        try runner.run([tools.appendingPathComponent("sign_update").path, "--account", account, combined.path])
        try runner.run([
            tools.appendingPathComponent("sign_update").path, "--account", account, "--verify", combined.path,
        ])
        if fresh.contains(where: { $0.tagName == "updates" }) {
            try runner.run(["gh", "release", "upload", "updates", "--repo", repository, "--clobber", combined.path])
        } else {
            try runner.run([
                "gh", "release", "create", "updates", "--repo", repository, "--target", revision, "--prerelease",
                "--latest=false",
                "--title", "Sparkle update feed", "--notes",
                "Signed Stable and Beta update feed. Download app releases from their versioned release pages.",
                combined.path,
            ])
        }
        print("Published https://github.com/\(repository)/releases/tag/\(tag)")
        print("Signed channel feed: \(config["feedURL"]!)")
    }
}
