import AppKit
import Testing
@testable import Schnaps

@MainActor @Test func escapeDismissesNewestAppearanceAndPreservesLayout() throws {
    let suite = "Schnaps.Escape.Tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let tools = DesignTools(defaults: defaults)
    let ruler = DesignMarker(tool: .ruler, display: 0)
    let guide = DesignMarker(tool: .guides, display: 0)
    tools.markers = [ruler]
    tools.visible = true
    tools.editing = true
    tools.loupe = true
    tools.markers.append(guide)
    tools.crosshair = true
    #expect(tools.dismissLastTool())
    #expect(!tools.crosshair && tools.loupe && tools.markers.allSatisfy(\.isVisible))
    #expect(tools.dismissLastTool())
    #expect(!tools.markers[1].isVisible && tools.markers[0].isVisible && tools.loupe)
    #expect(tools.dismissLastTool())
    #expect(!tools.loupe && tools.isActive)
    #expect(tools.dismissLastTool())
    #expect(!tools.isActive && !tools.editing && !tools.visible)
    #expect(!tools.dismissLastTool())
    #expect(tools.markers.count == 2)
    #expect(tools.markers[0].rect == ruler.rect)
    let restored = DesignTools(defaults: defaults)
    #expect(restored.markers.count == 2 && restored.markers.allSatisfy { !$0.isVisible })
}

@MainActor @Test func escapeSkipsDeletedHiddenAndDisabledToolsAndTracksRestoredMarkers() throws {
    let suite = "Schnaps.Escape.Tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let tools = DesignTools(defaults: defaults)
    let a = DesignMarker(tool: .frames, display: 0)
    let b = DesignMarker(tool: .guides, display: 0)
    tools.markers = [a, b]
    tools.visible = true
    tools.loupe = true
    tools.loupe = false
    tools.markers.removeLast()
    tools.crosshair = true
    // A restored marker becomes the most recent appearance, even if it is locked.
    tools.markers[0].isVisible = false
    tools.markers[0].locked = true
    tools.markers[0].isVisible = true
    #expect(tools.dismissLastTool())
    #expect(!tools.hasVisibleMarkers && tools.crosshair)
    #expect(tools.dismissLastTool())
    #expect(!tools.isActive && !tools.dismissLastTool())
    tools.visible = true
    #expect(!tools.isActive) // An all-hidden layout must not intercept mouse input.
}
