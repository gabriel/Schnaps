import Foundation

struct PublishError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
struct Runner {
    let root: URL
    var environment = ProcessInfo.processInfo.environment
    @discardableResult func run(_ args: [String], capture: Bool = false, captureStandardError: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = root
        process.environment = environment
        let pipe = Pipe()
        if capture { process.standardOutput = pipe }
        if captureStandardError { process.standardError = pipe }
        try process.run()
        let data = (capture || captureStandardError) ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let diagnostic = captureStandardError ? "\n" + String(decoding: data, as: UTF8.self) : ""
            throw PublishError("\(args.first ?? "Command") failed (\(process.terminationStatus)).\(diagnostic)")
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
enum NotarizationPreflight {
    static func validate(runner: Runner, profile: String) throws {
        do {
            try runner.run(
                ["xcrun", "notarytool", "history", "--keychain-profile", profile, "--output-format", "json"],
                capture: true, captureStandardError: true)
        } catch {
            let diagnostic = error.localizedDescription
            let normalized = diagnostic.lowercased()
            let guidance: String
            if normalized.contains("required_agreements_missing_or_expired")
                || normalized.contains("required agreement is missing or has expired")
                || normalized.contains("in-effect agreement") {
                guidance = "Apple notarization requires an updated agreement. Have the team's Account Holder sign in at https://developer.apple.com/account/ and accept the required agreements, then retry."
            } else if normalized.contains("no keychain password item found for profile") {
                guidance = "Notarization profile '\(profile)' is unavailable. Set SCHNAPS_NOTARY_PROFILE to an existing notarytool Keychain profile before publishing."
            } else {
                guidance = "Could not validate notarization access using profile '\(profile)'. Check the notarytool diagnostic below before retrying."
            }
            throw PublishError("\(guidance)\n\(diagnostic)")
        }
    }
}
