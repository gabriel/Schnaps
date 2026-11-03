import CoreGraphics
import Testing
@testable import Schnaps

@Test func loupeFlipsAwayFromPointerAtDisplayEdges() {
  let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
  let topLeft = LoupeGeometry.panel(at: CGPoint(x: 10, y: 10), in: bounds, size: 180)
  #expect(topLeft.minX > 10 && topLeft.minY > 10)
  let bottomRight = LoupeGeometry.panel(at: CGPoint(x: 990, y: 790), in: bounds, size: 180)
  #expect(bottomRight.maxX < 990 && bottomRight.maxY < 790)
  #expect(bounds.contains(bottomRight))
}
