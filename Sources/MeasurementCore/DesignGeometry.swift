import CoreGraphics
import Foundation

public enum DesignGeometry {
  public static func bestDisplay(for rect: CGRect, displays: [(id: UInt32, bounds: CGRect)])
    -> UInt32?
  {
    let areas = displays.map { display in
      let area = display.bounds.intersection(rect)
      return (display.id, area.isNull ? 0 : area.width * area.height)
    }
    guard let best = areas.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
    return best.0
  }
  public static func endpoint(origin: CGPoint, length: Double, degrees: Double) -> CGPoint {
    let angle = degrees * .pi / 180
    return CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
  }
  public static func distance(_ point: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> Double {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let squared = dx * dx + dy * dy
    guard squared > 0 else { return hypot(point.x - a.x, point.y - a.y) }
    let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / squared))
    return hypot(point.x - a.x - t * dx, point.y - a.y - t * dy)
  }
  public static func columnWidth(width: Double, columns: Int, margin: Double, gutter: Double)
    -> Double
  {
    max(0, (width - 2 * margin - Double(max(0, columns - 1)) * gutter) / Double(max(1, columns)))
  }
  public static func snapped(_ value: Double, step: Double) -> Double {
    guard step.isFinite, step > 0 else { return value }
    return (value / step).rounded() * step
  }
}

public struct InspectorColor: Equatable, Sendable {
  public let red: Double, green: Double, blue: Double
  public init(red: Double, green: Double, blue: Double) {
    self.red = max(0, min(1, red))
    self.green = max(0, min(1, green))
    self.blue = max(0, min(1, blue))
  }
  public var hex: String {
    String(
      format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()),
      Int((blue * 255).rounded()))
  }
  public var rgb: String {
    "rgb(\(Int((red*255).rounded())), \(Int((green*255).rounded())), \(Int((blue*255).rounded())))"
  }
  public var hsl: String {
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    let delta = high - low
    let light = (high + low) / 2
    let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * light - 1))
    var hue = 0.0
    if delta != 0 {
      if high == red {
        hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
      } else if high == green {
        hue = (blue - red) / delta + 2
      } else {
        hue = (red - green) / delta + 4
      }
      hue *= 60
      if hue < 0 { hue += 360 }
    }
    return String(format: "hsl(%.0f, %.0f%%, %.0f%%)", hue, saturation * 100, light * 100)
  }
  public var swift: String {
    String(format: "NSColor(srgbRed: %.4f, green: %.4f, blue: %.4f, alpha: 1)", red, green, blue)
  }
  public var luminance: Double {
    func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }
  public func contrast(with other: Self) -> Double {
    (max(luminance, other.luminance) + 0.05) / (min(luminance, other.luminance) + 0.05)
  }
}
