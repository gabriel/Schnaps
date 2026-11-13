import Foundation
import MeasurementCore
import Testing
@testable import Schnaps

@Test func findDimensionsLabelAlwaysShowsOnlyWidthAndHeight() {
    let rect = CGRect(x: 40, y: 100, width: 12, height: 65)
    for units in [true, false] {
        for indicators in [true, false] {
            let presentation = MeasurementPresentation(showUnits: units, showIndicators: indicators)
            #expect(FindDimensionsLabel.text(for: rect, presentation: presentation, scale: 2) == "12 × 65")
        }
    }
    let pixels = MeasurementPresentation(unit: .pixels, showUnits: true, showIndicators: true)
    #expect(FindDimensionsLabel.text(for: rect, presentation: pixels, scale: 2) == "24 × 130")
    let fractional = MeasurementPresentation(roundedPoints: false)
    #expect(FindDimensionsLabel.text(for: CGRect(x: 0, y: 0, width: 12.5, height: 65.25),
                                    presentation: fractional, scale: 2) == "12.5 × 65.25")
}

@Test func combinedLabelUsesCrosshairRatherThanSpanMidpoints() throws {
    let horizontal = DimensionSpan(start: CGPoint(x: 20, y: 160), end: CGPoint(x: 720, y: 160))
    let vertical = DimensionSpan(start: CGPoint(x: 100, y: 30), end: CGPoint(x: 100, y: 530))
    let dimensions = try #require(FindDimensionsLabel.pair(horizontal, vertical))
    let center = CGPoint(x: dimensions.vertical.start.x, y: dimensions.horizontal.start.y)
    for width: CGFloat in [80, 160, 240] {
        let rect = FindDimensionsLabel.frame(at: center, size: CGSize(width: width, height: 28),
                                             in: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(rect.origin == CGPoint(x: 110, y: 170))
    }
}

@Test func combinedLabelStaysInsideDisplayAtEdges() {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    for center in [CGPoint.zero, CGPoint(x: 800, y: 600)] {
        let rect = FindDimensionsLabel.frame(at: center, size: CGSize(width: 120, height: 28), in: bounds)
        #expect(bounds.insetBy(dx: 8, dy: 8).contains(rect))
    }
}

@Test func independentPinnedSpansAreNotCombinedUnlessTheyCross() {
    let horizontal = DimensionSpan(start: CGPoint(x: 20, y: 160), end: CGPoint(x: 720, y: 160))
    let vertical = DimensionSpan(start: CGPoint(x: 750, y: 30), end: CGPoint(x: 750, y: 530))
    #expect(FindDimensionsLabel.pair(horizontal, vertical) == nil)
    #expect(FindDimensionsLabel.pair(horizontal, horizontal) == nil)
    #expect(FindDimensionsLabel.pair(vertical, horizontal) == nil)
}

@Test func snapCapsuleStaysBelowDimensionsAtEveryDisplayEdge() throws {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    for center in [CGPoint.zero, CGPoint(x: 800, y: 600), CGPoint(x: 400, y: 300)] {
        for width: CGFloat in [30, 160] {
            let layout = FindDimensionsLabel.layout(at: center, width: width, snapWidth: 60, in: bounds)
            let snap = try #require(layout.snap)
            #expect(snap.minY == layout.measurement.maxY + 4)
            #expect(snap.midX == layout.measurement.midX)
            #expect(bounds.insetBy(dx: 8, dy: 8).contains(snap))
            #expect(bounds.insetBy(dx: 8, dy: 8).contains(layout.measurement))
        }
    }
    let plain = FindDimensionsLabel.layout(at: .zero, width: 120, snapWidth: nil, in: bounds)
    #expect(plain.snap == nil)
    #expect(plain.measurement == FindDimensionsLabel.frame(at: .zero, size: CGSize(width: 120, height: 28), in: bounds))
}
