import Foundation
import MeasurementCore
import Testing
@testable import Schnaps

private let canvas = CGRect(x: 0, y: 0, width: 800, height: 600)
private let verticalSpan = DimensionSpan(start: CGPoint(x: 400, y: 100), end: CGPoint(x: 400, y: 500))

@Test func verticalDimensionLabelIsCenteredAndClearsLineAtDifferentTextWidths() {
    for width: CGFloat in [40, 120, 240] {
        let rect = DimensionLabelPlacement.frame(for: verticalSpan, size: CGSize(width: width, height: 28),
                                                 in: canvas, avoiding: [])
        #expect(rect.midY == 300)
        #expect(rect.minX == 410)
    }
}

@Test func collidingVerticalLabelSwitchesSidesWithoutDriftingDown() {
    let size = CGSize(width: 100, height: 28)
    let first = DimensionLabelPlacement.frame(for: verticalSpan, size: size, in: canvas, avoiding: [])
    let next = DimensionLabelPlacement.frame(for: verticalSpan, size: size, in: canvas, avoiding: [first])
    #expect(next.midY == first.midY)
    #expect(next.maxX == 390)
    #expect(!next.intersects(first))
}

@Test func horizontalDimensionLabelSwitchesAboveLineWhenBlocked() {
    let span = DimensionSpan(start: CGPoint(x: 100, y: 300), end: CGPoint(x: 700, y: 300))
    let first = DimensionLabelPlacement.frame(for: span, size: CGSize(width: 100, height: 28), in: canvas, avoiding: [])
    let next = DimensionLabelPlacement.frame(for: span, size: first.size, in: canvas, avoiding: [first])
    #expect(first.midX == 400)
    #expect(first.minY == 310)
    #expect(next.midX == 400)
    #expect(next.maxY == 290)
}

@Test func dimensionLabelsStayInsideDisplayAtEveryEdge() {
    let safe = canvas.insetBy(dx: 8, dy: 8)
    for point in [CGPoint.zero, CGPoint(x: 800, y: 0), CGPoint(x: 0, y: 600), CGPoint(x: 800, y: 600)] {
        for end in [CGPoint(x: point.x + 1, y: point.y), CGPoint(x: point.x, y: point.y + 1)] {
            let rect = DimensionLabelPlacement.frame(for: DimensionSpan(start: point, end: end),
                size: CGSize(width: 200, height: 28), in: canvas, avoiding: [])
            #expect(safe.contains(rect))
        }
    }
}

@Test func crowdedDimensionLabelsRemainNearTheirSpan() {
    let rect = DimensionLabelPlacement.frame(for: verticalSpan, size: CGSize(width: 100, height: 28),
                                             in: canvas, avoiding: [canvas])
    #expect(rect.midY == 300)
    #expect(rect.minX == 410)
}

@Test func verticalDimensionLabelUsesLeftSideNearRightDisplayEdge() {
    let span = DimensionSpan(start: CGPoint(x: 780, y: 100), end: CGPoint(x: 780, y: 500))
    let rect = DimensionLabelPlacement.frame(for: span, size: CGSize(width: 160, height: 28),
                                             in: canvas, avoiding: [])
    #expect(rect.maxX == 770)
    #expect(rect.midY == 300)
}
