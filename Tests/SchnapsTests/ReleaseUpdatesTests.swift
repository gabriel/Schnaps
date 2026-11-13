import Testing
@testable import Schnaps

@Test func releaseUpdatesRequireThePublishedAppIdentity() {
    #expect(ReleaseUpdates.supports(configuration: "release", bundleIdentifier: "com.gabrielhandford.Schnap"))
    #expect(!ReleaseUpdates.supports(configuration: "debug", bundleIdentifier: "com.gabrielhandford.Schnap"))
    #expect(!ReleaseUpdates.supports(configuration: "debug", bundleIdentifier: "com.gabrielhandford.Schnap.debug"))
    #expect(!ReleaseUpdates.supports(configuration: "release", bundleIdentifier: "com.gabrielhandford.Schnap.debug"))
    #expect(!ReleaseUpdates.supports(configuration: nil, bundleIdentifier: nil))
}
