import AppKit
import MeasurementCore

extension DesignMarker {
  /// Marker coordinates use the owning display's top-left, in logical points.
  func projected(from source: CGRect, to target: CGRect) -> DesignMarker {
    var result = self
    result.x += source.minX - target.minX
    result.y += target.maxY - source.maxY
    return result
  }

  func containsEditingPoint(_ point: CGPoint) -> Bool {
    switch tool {
    case .ruler:
      return DesignGeometry.distance(point, toSegmentFrom: CGPoint(x: x, y: y), to: end) < 20
    case .guides:
      return abs(vertical ? point.x - x : point.y - y) < 10
    default:
      return rect.insetBy(dx: -8, dy: -8).contains(point)
    }
  }
}
