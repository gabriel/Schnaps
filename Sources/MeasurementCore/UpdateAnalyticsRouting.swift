import Foundation

/// Proxy requests without rewriting the signed feed or archive bytes.
public enum UpdateAnalyticsRouting {
    public static func proxyURL(for upstream: URL) -> URL? {
        guard upstream.scheme == "https", upstream.host == "github.com",
              upstream.user == nil, upstream.password == nil, upstream.port == nil,
              upstream.query == nil, upstream.fragment == nil else { return nil }
        let pattern = #"^/gabriel/Schnaps/releases/download/(v?[0-9]+\.[0-9]+\.[0-9]+(?:-beta\.[0-9]+)?)/(Schnaps-([0-9]+\.[0-9]+\.[0-9]+(?:-beta\.[0-9]+)?)\.(?:dmg|delta))$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: upstream.path, range: NSRange(upstream.path.startIndex..., in: upstream.path)),
              let tagRange = Range(match.range(at: 1), in: upstream.path),
              let fileRange = Range(match.range(at: 2), in: upstream.path),
              let versionRange = Range(match.range(at: 3), in: upstream.path) else { return nil }
        let tag = String(upstream.path[tagRange])
        guard tag.replacingOccurrences(of: "^v", with: "", options: .regularExpression) == upstream.path[versionRange] else { return nil }
        return URL(string: "https://getschnaps.com/updates/artifacts/\(tag)/\(upstream.path[fileRange])")
    }
}
