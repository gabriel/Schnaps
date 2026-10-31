import CoreGraphics
import Foundation
import Testing

@testable import MeasurementCore

@Test func rulersHandleRotationAndDegenerateSegments() {
  let point = DesignGeometry.endpoint(origin: CGPoint(x: 10, y: 20), length: 100, degrees: 90)
  #expect(abs(point.x - 10) < 0.0001)
  #expect(abs(point.y - 120) < 0.0001)
  #expect(
    DesignGeometry.distance(CGPoint(x: 50, y: 30), toSegmentFrom: .zero, to: CGPoint(x: 100, y: 0))
      == 30)
  #expect(DesignGeometry.distance(CGPoint(x: 3, y: 4), toSegmentFrom: .zero, to: .zero) == 5)
  #expect(
    DesignGeometry.distance(CGPoint(x: 110, y: 0), toSegmentFrom: .zero, to: CGPoint(x: 100, y: 0))
      == 10)
  #expect(DesignGeometry.columnWidth(width: 960, columns: 12, margin: 24, gutter: 16) == 736.0 / 12)
  #expect(DesignGeometry.columnWidth(width: 10, columns: 12, margin: 24, gutter: 16) == 0)
  #expect(DesignGeometry.snapped(-12, step: 10) == -10)
}

@Test func colorFormattingAndContrastUseLinearSRGB() {
  let black = InspectorColor(red: 0, green: 0, blue: 0)
  let white = InspectorColor(red: 1, green: 1, blue: 1)
  #expect(black.contrast(with: white) == 21)
  #expect(white.contrast(with: black) == 21)
  #expect(white.contrast(with: white) == 1)
  #expect(InspectorColor(red: 1, green: 0, blue: 0).hsl == "hsl(0, 100%, 50%)")
  #expect(InspectorColor(red: 0, green: 1, blue: 0).hsl == "hsl(120, 100%, 50%)")
  #expect(InspectorColor(red: 1, green: 0.5, blue: 0).hex == "#FF8000")
  #expect(InspectorColor(red: 1, green: 1, blue: 1).hsl == "hsl(0, 0%, 100%)")
}

@Test func textEncodingsRoundTripUnicodeAndReservedCharacters() throws {
  let text = "A & <\"é\"> /+ 😀\n\t\0"
  for format in TextEncodingFormat.allCases {
    #expect(try TextCodec.decode(TextCodec.encode(text, as: format), from: format) == text)
  }
  #expect(TextCodec.encode("/+?=&", as: .url) == "%2F%2B%3F%3D%26")
  #expect(
    try TextCodec.decode("&CounterClockwiseContourIntegral; &Afr; &NotEqualTilde;", from: .html)
      == "∳ 𝔄 ≂̸")
  #expect(try TextCodec.decode("&lt;script&gt;&amp;", from: .html) == "<script>&")
  #expect(throws: TextCodecError.self) { try TextCodec.decode("%GG", from: .url) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("FF", from: .bytes) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("0", from: .bytes) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("\\uD800", from: .cString) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("\\x", from: .cString) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("U+110000", from: .named) }
  #expect(TextCodec.repairMojibake("cafÃ©") == "café")
}

@Test func palettesUseNamedACOAndRejectTruncatedOrInvalidData() throws {
  let colors = [
    InspectorColor(red: 1, green: 0, blue: 0), InspectorColor(red: 0, green: 1, blue: 0),
    InspectorColor(red: 0.2, green: 0.4, blue: 0.6),
  ]
  let data = ColorPalette.aco(colors)
  #expect(try ColorPalette.readACO(data).map(\.hex) == colors.map(\.hex))
  let v1Length = 4 + 10 * colors.count
  #expect(
    try ColorPalette.readACO(data.subdata(in: v1Length..<data.count)).map(\.hex)
      == colors.map(\.hex))
  #expect(throws: TextCodecError.self) { try ColorPalette.readACO(Data(data.prefix(7))) }
  #expect(throws: TextCodecError.self) { try ColorPalette.readACO(Data([0, 3, 0, 0])) }
  #expect(InspectorColor(hex: "#aabbcc")?.formatted("Short hex") == "#ABC")
  #expect(InspectorColor(hex: "#123456")?.formatted("Short hex") == "#123456")
  #expect(InspectorColor(red: 1, green: 1, blue: 1).formatted("Lab").hasPrefix("Lab D65(100.00"))
}

@Test func fontAwesomeNamesIncludeCanonicalNamesAndAliases() {
  #expect(FontAwesomeNames.values["heart"] == 0xf004)
  #expect(FontAwesomeNames.values["remove"] == FontAwesomeNames.values["times"])
  #expect(FontAwesomeNames.values.count == 786)
}

@Test func attachedWindowsChooseTheirCurrentDisplayInGlobalCaptureCoordinates() {
  let displays: [(id: UInt32, bounds: CGRect)] = [
    (1, CGRect(x: 0, y: 0, width: 1512, height: 982)),
    (2, CGRect(x: -2560, y: 0, width: 2560, height: 1440)),
    (3, CGRect(x: 0, y: -1080, width: 1920, height: 1080)),
  ]
  #expect(
    DesignGeometry.bestDisplay(
      for: CGRect(x: 100, y: 200, width: 230, height: 408), displays: displays) == 1)
  #expect(
    DesignGeometry.bestDisplay(
      for: CGRect(x: -1000, y: 200, width: 800, height: 600), displays: displays) == 2)
  #expect(
    DesignGeometry.bestDisplay(
      for: CGRect(x: 100, y: -900, width: 800, height: 600), displays: displays) == 3)
  #expect(
    DesignGeometry.bestDisplay(
      for: CGRect(x: 99999, y: 99999, width: 100, height: 100), displays: displays) == nil)
}

@Test func cEscapesDecodeUTF8BytesAndOctalWithoutChangingNullFollowedByDigits() throws {
  #expect(try TextCodec.decode(#""\xC3\xA9\012""#, from: .cString) == "é\n")
  #expect(try TextCodec.decode(TextCodec.encode("\07", as: .cString), from: .cString) == "\07")
  #expect(throws: TextCodecError.self) { try TextCodec.decode(#"\xFF"#, from: .cString) }
  #expect(throws: TextCodecError.self) { try TextCodec.decode("&#x110000;", from: .html) }
}
