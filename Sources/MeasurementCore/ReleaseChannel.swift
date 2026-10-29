import Foundation

public enum UpdateChannel: String, CaseIterable, Sendable {
    case stable, beta
    public var title: String { self == .stable ? "Stable" : "Beta" }
    public var allowedSparkleChannels: Set<String> { self == .beta ? ["beta"] : [] }
    public static func selected(saved: String?, bundled: String?) -> Self {
        saved.flatMap(Self.init(rawValue:)) ?? bundled.flatMap(Self.init(rawValue:)) ?? .stable
    }
}

public struct ReleaseVersion: Equatable, Comparable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let beta: Int?
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }
        let numbers = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3, numbers.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
            let major = Int(numbers[0]), let minor = Int(numbers[1]), let patch = Int(numbers[2])
        else { return nil }
        var beta: Int?
        if parts.count == 2 {
            guard parts[1].hasPrefix("beta."), let number = Int(parts[1].dropFirst(5)), number > 0 else { return nil }
            beta = number
        }
        self.major = major
        self.minor = minor
        self.patch = patch
        self.beta = beta
    }
    public var base: String { "\(major).\(minor).\(patch)" }
    public var string: String { base + (beta.map { "-beta.\($0)" } ?? "") }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.beta, rhs.beta) {
        case (.none, .none): return false
        case (.none, .some): return false
        case (.some, .none): return true
        case (.some(let a), .some(let b)): return a < b
        }
    }
}

public enum ReleasePlanning {
    public enum Failure: Error { case invalidVersion, exhaustedBuildNumber }
    public static func nextBeta(configured: String, known: [String], requested: String? = nil) throws -> ReleaseVersion
    {
        guard let configured = ReleaseVersion(configured), configured.beta == nil else { throw Failure.invalidVersion }
        let releases = known.compactMap(ReleaseVersion.init)
        let stable = releases.filter { $0.beta == nil }.max()
        let existingBetaBase = releases.filter { $0.beta != nil }.max().flatMap { ReleaseVersion($0.base) }
        let target: ReleaseVersion
        if let requested {
            guard let version = ReleaseVersion(requested), version.beta == nil,
                stable.map({ version > $0 }) ?? true,
                existingBetaBase.map({ version >= $0 }) ?? true
            else { throw Failure.invalidVersion }
            target = version
        } else {
            var minimum = configured
            if let stable, minimum <= stable {
                guard stable.patch < Int.max,
                    let next = ReleaseVersion("\(stable.major).\(stable.minor).\(stable.patch+1)")
                else { throw Failure.invalidVersion }
                minimum = next
            }
            target = max(minimum, existingBetaBase ?? minimum)
        }
        let previous = releases.filter { $0.base == target.base }.compactMap(\.beta).max() ?? 0
        guard previous < Int.max, let next = ReleaseVersion("\(target.base)-beta.\(previous+1)") else {
            throw Failure.invalidVersion
        }
        return next
    }
    public static func nextBuild(configured: Int, published: [Int]) throws -> Int {
        let latest = max(0, published.max() ?? 0)
        guard latest < Int.max else { throw Failure.exhaustedBuildNumber }
        return max(configured, latest + 1)
    }
}
