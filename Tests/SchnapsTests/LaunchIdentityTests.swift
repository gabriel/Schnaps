import Foundation
import XCTest
@testable import Schnaps

final class LaunchIdentityTests: XCTestCase {
    @MainActor
    func testIdentityIsSchnapsOnlyAndStableAcrossUpdates() throws {
        let suite = "SchnapsAnalyticsTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let unrelatedRELID = UUID().uuidString
        defaults.set(unrelatedRELID, forKey: "RELAnalyticsInstallationID")
        _ = SchnapsLaunchReporter(defaults: defaults, version: "0.7.4", build: "16")
        let first = try XCTUnwrap(defaults.string(forKey: "SchnapsAnalyticsInstallationID"))
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertNotEqual(first, unrelatedRELID)
        _ = SchnapsLaunchReporter(defaults: defaults, version: "0.8.0-beta.1", build: "17")
        XCTAssertEqual(defaults.string(forKey: "SchnapsAnalyticsInstallationID"), first)
        XCTAssertEqual(defaults.string(forKey: "RELAnalyticsInstallationID"), unrelatedRELID)
    }
}
