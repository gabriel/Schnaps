import Foundation
import MeasurementCore
import Testing

@testable import Schnaps

@MainActor @Test func betaOptInSurvivesReceivingAStableBuild() {
    let name = "SchnapsChannelTests.\(UUID().uuidString)"
    // Use an isolated suite; never change the installed app's preferences.
    let isolated = UserDefaults(suiteName: name)!
    defer { isolated.removePersistentDomain(forName: name) }
    let beta = UpdateChannelSettings(defaults: isolated, bundledChannel: "beta")
    #expect(beta.channel == .beta)
    let stable = UpdateChannelSettings(defaults: isolated, bundledChannel: "stable")
    #expect(stable.channel == .beta)
    stable.channel = .stable
    let nextBeta = UpdateChannelSettings(defaults: isolated, bundledChannel: "beta")
    #expect(nextBeta.channel == .stable)
}
