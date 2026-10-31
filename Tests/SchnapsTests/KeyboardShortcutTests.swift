import AppKit
import Carbon
import Testing
@testable import Schnaps

@MainActor @Test func shortcutEditsAndClearingSurviveRestartAndReset() throws {
    let suite = "Schnaps.ShortcutTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = ShortcutSettings(defaults: defaults)
    #expect(settings.binding(for: .dimensions).label == "⇧⌘F")
    let custom = ShortcutBinding.make(kVK_ANSI_D, "d", [.command, .option])
    #expect(settings.set(custom, for: .dimensions) == nil)
    var cleared = settings.binding(for: .area); cleared.enabled = false
    #expect(settings.set(cleared, for: .area) == nil)
    let reopened = ShortcutSettings(defaults: defaults)
    #expect(reopened.binding(for: .dimensions) == custom)
    #expect(!reopened.binding(for: .area).enabled)
    #expect(reopened.binding(for: .area).label == "None")
    reopened.reset()
    let restored = ShortcutSettings(defaults: defaults)
    #expect(ShortcutAction.allCases.allSatisfy { restored.binding(for: $0) == $0.defaultBinding })
    #expect(custom.carbonModifiers == UInt32(cmdKey | optionKey))
}

@MainActor @Test func shortcutConflictsAreRejectedWithoutLosingPreviousBinding() throws {
    let suite = "Schnaps.ShortcutTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = ShortcutSettings(defaults: defaults)
    let original = settings.binding(for: .dimensions)
    #expect(settings.set(settings.binding(for: .area), for: .dimensions)?.contains("Measure Area") == true)
    #expect(settings.set(.make(kVK_ANSI_Q, "q", .command), for: .dimensions) != nil)
    #expect(settings.set(.make(kVK_ANSI_C, "c", .command), for: .dimensions) != nil)
    #expect(settings.set(.make(kVK_ANSI_D, "d", .shift), for: .dimensions) != nil)
    #expect(settings.set(.make(kVK_Return, "\r", .command), for: .dimensions) != nil)
    settings.checkAvailability = { _ in false }
    #expect(settings.set(.make(kVK_ANSI_D, "d", [.command, .option]), for: .dimensions)?.contains("another app") == true)
    #expect(settings.binding(for: .dimensions) == original)
    #expect(ShortcutSettings(defaults: defaults).binding(for: .dimensions) == original)
}
