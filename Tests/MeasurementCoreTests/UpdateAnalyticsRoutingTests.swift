import Foundation
import XCTest
@testable import MeasurementCore

final class UpdateAnalyticsRoutingTests: XCTestCase {
    func testOnlyImmutableSchnapsArchivesAreProxied() throws {
        let original = try XCTUnwrap(URL(string: "https://github.com/gabriel/Schnaps/releases/download/v0.7.4/Schnaps-0.7.4.dmg"))
        XCTAssertEqual(UpdateAnalyticsRouting.proxyURL(for: original)?.absoluteString, "https://getschnaps.com/updates/artifacts/v0.7.4/Schnaps-0.7.4.dmg")
        for raw in ["https://example.com/gabriel/Schnaps/releases/download/v0.7.4/Schnaps-0.7.4.dmg", "https://github.com/other/repo/releases/download/v0.7.4/Schnaps-0.7.4.dmg", "https://github.com/gabriel/Schnaps/releases/download/v0.7.3/Schnaps-0.7.4.dmg"] {
            XCTAssertNil(UpdateAnalyticsRouting.proxyURL(for: try XCTUnwrap(URL(string: raw))))
        }
    }
}
