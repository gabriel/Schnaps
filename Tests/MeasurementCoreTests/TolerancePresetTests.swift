import Testing
@testable import MeasurementCore

@Test func tolerancePresetsMigrateOldSliderValues() {
    #expect(TolerancePreset.allCases.map(\.rawValue) == [0, 8, 18, 36])
    #expect(TolerancePreset.closest(to: 0) == .zero)
    #expect(TolerancePreset.closest(to: 12) == .low)
    #expect(TolerancePreset.closest(to: 18) == .medium)
    #expect(TolerancePreset.closest(to: 30) == .high)
    #expect(TolerancePreset.closest(to: Int.min) == .zero)
    #expect(TolerancePreset.closest(to: Int.max) == .high)
}

@Test func toleranceScrollStopsAtEndpointsAndKeyboardWraps() {
    #expect(TolerancePreset.zero.stepped(by: -1) == .zero)
    #expect(TolerancePreset.medium.stepped(by: 1) == .high)
    #expect(TolerancePreset.low.stepped(by: -1) == .zero)
    #expect(TolerancePreset.high.stepped(by: Int.max) == .high)
    #expect(TolerancePreset.zero.stepped(by: Int.min) == .zero)
    #expect(TolerancePreset.high.cycled() == .zero)
    #expect(TolerancePreset.zero.cycled(backward: true) == .high)
}
