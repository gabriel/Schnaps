import Foundation
import Testing

@testable import MeasurementCore

@Test func channelSelectionPreservesOptInAndDefaultsSafely() {
    #expect(UpdateChannel.selected(saved: nil, bundled: nil) == .stable)
    #expect(UpdateChannel.selected(saved: nil, bundled: "beta") == .beta)
    #expect(UpdateChannel.selected(saved: "stable", bundled: "beta") == .stable)
    #expect(UpdateChannel.selected(saved: "beta", bundled: "stable") == .beta)
    #expect(UpdateChannel.selected(saved: "invalid", bundled: "invalid") == .stable)
    #expect(UpdateChannel.stable.allowedSparkleChannels.isEmpty)
    #expect(UpdateChannel.beta.allowedSparkleChannels == ["beta"])
}

@Test func betaPlanningAdvancesVersionsWithoutChangingStableConfiguration() throws {
    #expect(try ReleasePlanning.nextBeta(configured: "0.6.2", known: ["0.6.2"]).string == "0.6.3-beta.1")
    #expect(
        try ReleasePlanning.nextBeta(configured: "0.6.2", known: ["0.6.2", "0.6.3-beta.1"]).string == "0.6.3-beta.2")
    #expect(try ReleasePlanning.nextBeta(configured: "0.7.0", known: ["0.6.2"]).string == "0.7.0-beta.1")
    #expect(
        try ReleasePlanning.nextBeta(configured: "0.6.2", known: ["0.6.2", "0.8.0-beta.4"]).string == "0.8.0-beta.5")
    #expect(
        try ReleasePlanning.nextBeta(configured: "0.6.2", known: ["0.6.2"], requested: "1.0.0").string == "1.0.0-beta.1"
    )
    #expect(throws: ReleasePlanning.Failure.self) {
        try ReleasePlanning.nextBeta(configured: "0.6.2", known: ["0.6.2"], requested: "0.6.2")
    }
    #expect(try ReleasePlanning.nextBuild(configured: 8, published: [8, 9, 12]) == 13)
    #expect(try ReleasePlanning.nextBuild(configured: 50, published: [12]) == 50)
    #expect(throws: ReleasePlanning.Failure.self) { try ReleasePlanning.nextBuild(configured: 8, published: [Int.max]) }
    #expect(ReleaseVersion("0.7.0-beta.1")! < ReleaseVersion("0.7.0")!)
    for invalid in ["../0.7.0", "1.0", "1.0.0-beta.0", "1.0.0-rc.1", "1.0.0/evil"] {
        #expect(ReleaseVersion(invalid) == nil)
    }
}

private func feed(_ build: Int, _ version: String, beta: Bool = false, file: String? = nil) -> Data {
    Data(
        """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel><title>Schnaps</title><item>
        <sparkle:version>\(build)</sparkle:version><sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
        \(beta ? "<sparkle:channel>beta</sparkle:channel>" : "")
        <enclosure url="https://github.com/gabriel/Schnaps/releases/download/v\(version)/\(file ?? "Schnaps.dmg")" sparkle:edSignature="\(Data(repeating:0,count:64).base64EncodedString())" length="100" type="application/octet-stream"/>
        </item></channel></rss>
        """.utf8)
}

@Test func combinedFeedKeepsStableAndBetaAndRejectsCollidingBuilds() throws {
    let stable = feed(8, "0.6.2")
    let beta = feed(9, "0.6.3-beta.1", beta: true)
    let merged = try ReleaseFeed.merge([stable, beta, stable])
    let entries = try ReleaseFeed.entries(merged)
    #expect(entries.map(\.build) == [9, 8])
    #expect(entries.filter { $0.channel == .stable }.map(\.version) == ["0.6.2"])
    #expect(
        entries.filter {
            UpdateChannel.beta.allowedSparkleChannels.contains($0.channel.rawValue) || $0.channel == .stable
        }.count == 2)
    #expect(throws: ReleaseFeed.Failure.self) {
        try ReleaseFeed.merge([beta, feed(9, "0.6.3-beta.1", beta: true, file: "other.dmg")])
    }
    let many = try ReleaseFeed.merge((1...15).map { feed($0, "0.1.\($0)", beta: true) } + [feed(100, "1.0.0")])
    #expect(try ReleaseFeed.entries(many).filter { $0.channel == .beta }.count == 10)
    #expect(throws: ReleaseFeed.Failure.self) {
        try ReleaseFeed.entries(Data("<rss><channel><item/></channel></rss>".utf8))
    }
}
