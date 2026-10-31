import Foundation
import Testing
@testable import Schnaps

@Test func toolOverlayVisibilityIsOptInAndSurvivesRestarts() throws {
    let suite = "Schnaps.ToolOverlay.Tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = ToolOverlayPreferences(defaults: defaults)
    #expect(!preferences.isEnabled)
    preferences.isEnabled = true
    let restored = ToolOverlayPreferences(defaults: try #require(UserDefaults(suiteName: suite)))
    #expect(restored.isEnabled)
    restored.isEnabled = false
    #expect(!ToolOverlayPreferences(defaults: defaults).isEnabled)
}
