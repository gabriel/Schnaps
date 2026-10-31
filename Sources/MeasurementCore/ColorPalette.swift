import Foundation

extension InspectorColor {
  public init?(hex: String) {
    let text = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
  public func formatted(_ name: String) -> String {
    switch name {
    case "RGB": return rgb
    case "HSL": return hsl
    case "HSB":
      let hi = max(red, green, blue)
      let lo = min(red, green, blue)
      let delta = hi - lo
      var hue = 0.0
      if delta > 0 {
        if hi == red {
          hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if hi == green {
          hue = (blue - red) / delta + 2
        } else {
          hue = (red - green) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
      }
      return String(
        format: "hsb(%.0f°, %.0f%%, %.0f%%)", hue, (hi == 0 ? 0 : delta / hi) * 100, hi * 100)
    case "Lab":
      func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
      }
      let r = linear(red)
      let g = linear(green)
      let b = linear(blue)
      func f(_ t: Double) -> Double {
        t > 216.0 / 24389 ? pow(t, 1.0 / 3) : (24389.0 / 27 * t + 16) / 116
      }
      let x = f((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047)
      let y = f(0.2126729 * r + 0.7151522 * g + 0.072175 * b)
      let z = f((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / 1.08883)
      return String(format: "Lab D65(%.2f, %.2f, %.2f)", 116 * y - 16, 500 * (x - y), 200 * (y - z))
    case "Swift": return swift
    case "SwiftUI":
      return String(format: "Color(.sRGB, red: %.4f, green: %.4f, blue: %.4f)", red, green, blue)
    case "UIColor":
      return String(
        format: "UIColor(red: %.4f, green: %.4f, blue: %.4f, alpha: 1)", red, green, blue)
    case "Short hex":
      let chars = Array(hex.dropFirst())
      if chars[0] == chars[1] && chars[2] == chars[3] && chars[4] == chars[5] {
        return "#" + String([chars[0], chars[2], chars[4]])
      }
      return hex
    default: return hex
    }
  }
}

/// Adobe's public ACO specification. Exports RGB v1 + named RGB v2 for broad compatibility.
public enum ColorPalette {
  public static func aco(_ colors: [InspectorColor]) -> Data {
    let colors = Array(colors.prefix(128))
    var data = Data()
    func word(_ value: UInt16) {
      data.append(UInt8(value >> 8))
      data.append(UInt8(value & 255))
    }
    for version in [1, 2] {
      word(UInt16(version))
      word(UInt16(colors.count))
      for color in colors {
        word(0)
        word(UInt16((color.red * 65535).rounded()))
        word(UInt16((color.green * 65535).rounded()))
        word(UInt16((color.blue * 65535).rounded()))
        word(0)
        if version == 2 {
          let name = Array(color.hex.utf16)
          word(0)
          word(UInt16(name.count + 1))
          for unit in name { word(unit) }
          word(0)
        }
      }
    }
    return data
  }
  public static func readACO(_ data: Data) throws -> [InspectorColor] {
    guard data.count <= 1_000_000 else { throw TextCodecError.invalid("Palette is too large.") }
    let bytes = Array(data)
    var position = 0
    func word() throws -> UInt16 {
      guard position + 2 <= bytes.count else {
        throw TextCodecError.invalid("Truncated ACO palette.")
      }
      defer { position += 2 }
      return UInt16(bytes[position]) << 8 | UInt16(bytes[position + 1])
    }
    let version = try word()
    let count = Int(try word())
    guard [1, 2].contains(version), count <= 128 else {
      throw TextCodecError.invalid("Choose an RGB ACO palette with up to 128 colors.")
    }
    var colors: [InspectorColor] = []
    for _ in 0..<count {
      let space = try word()
      let r = try word()
      let g = try word()
      let b = try word()
      _ = try word()
      guard space == 0 else {
        throw TextCodecError.invalid(
          "This ACO uses a non-RGB color space. Convert it to RGB before importing.")
      }
      colors.append(
        InspectorColor(red: Double(r) / 65535, green: Double(g) / 65535, blue: Double(b) / 65535))
      if version == 2 {
        let high = try word()
        let low = try word()
        let units = Int(high) << 16 | Int(low)
        guard units <= 10000, position + units * 2 <= bytes.count else {
          throw TextCodecError.invalid("Invalid ACO color name.")
        }
        position += units * 2
      }
    }
    return colors
  }
}
