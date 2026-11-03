import AppKit
import MeasurementCore
import Testing
@testable import Schnaps

@Test func loupeUsesPhysicalPixelsAndCentersNudges() {
  for scale: CGFloat in [1.0, 2.0] {
    let selection = LoupeSelection(point: CGPoint(x: 10.8, y: 20.1), scaleX: scale, scaleY: scale,
                                   imageSize: CGSize(width: 200, height: 100))
    #expect(selection.pixel == CGPoint(x: floor(10.8 * scale), y: floor(20.1 * scale)))
    let right = selection.moved(dx: 1, dy: 0)
    #expect(right.x * scale == selection.pixel.x + 1.5)
    #expect(right.y * scale == selection.pixel.y + 0.5)
    #expect(selection.moved(dx: 0, dy: -10).y * scale == selection.pixel.y - 9.5)
    for zoom: CGFloat in [2.0, 8.0, 13.7, 32.0] {
      let rect = selection.sourceRect(size: 180, zoom: zoom)
      #expect(rect.midX == selection.pixel.x + 0.5)
      #expect(rect.midY == selection.pixel.y + 0.5)
      #expect(rect.width * zoom >= 180)
      #expect(rect == rect.integral)
    }
  }
}

@Test func loupeNudgesStopAtImageEdges() {
  let selection = LoupeSelection(point: .zero, scaleX: 2, scaleY: 2,
                                 imageSize: CGSize(width: 200, height: 100))
  #expect(selection.moved(dx: -10, dy: -10) == CGPoint(x: 0.25, y: 0.25))
  #expect(selection.moved(dx: 1000, dy: 1000) == CGPoint(x: 99.75, y: 49.75))
}

@MainActor @Test func clearingLoupePinDoesNotRepeatRedraw() throws {
  let suite = "Schnaps.Loupe.Redraw.Tests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let tools = DesignTools(defaults: defaults)
  var redraws = 0
  tools.redraw = {
    redraws += 1
    // The controller clears a pin when all tools are dismissed.
    if tools.frozenLoupe == nil { tools.frozenLoupe = nil }
  }
  defer { tools.redraw = nil }
  tools.frozenLoupe = CGPoint(x: 10, y: 20)
  tools.frozenLoupe = nil
  #expect(redraws == 2)
}

@MainActor @Test func loupeKeyboardWorksWithoutMarkerEditing() throws {
  let screen = try #require(NSScreen.screens.first)
  let suite = "Schnaps.Loupe.Tests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let tools = DesignTools(defaults: defaults)
  tools.loupe = true
  tools.frozenLoupe = CGPoint(x: screen.frame.minX + 10.25, y: screen.frame.maxY - 20.25)
  let canvas = DesignCanvas(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: tools)
  let context = try #require(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8,
                                     bytesPerRow: 800, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
  let image = try #require(context.makeImage())
  let pixels = try #require(PixelBuffer(image: image))
  canvas.snapshot = { ScreenSnapshot(image: image, pixels: pixels, scaleX: 2, scaleY: 2) }
  func press(_ key: UInt16, characters: String = "", flags: NSEvent.ModifierFlags = [], repeatKey: Bool = false) throws {
    let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                            timestamp: 0, windowNumber: 0, context: nil, characters: characters,
                                            charactersIgnoringModifiers: characters, isARepeat: repeatKey, keyCode: key))
    canvas.keyDown(with: event)
  }
  try press(124)
  #expect(!tools.editing)
  #expect(tools.frozenLoupe == CGPoint(x: screen.frame.minX + 10.75, y: screen.frame.maxY - 20.25))
  try press(126, flags: .shift)
  #expect(tools.frozenLoupe == CGPoint(x: screen.frame.minX + 10.75, y: screen.frame.maxY - 15.25))
  try press(8, characters: "c", flags: .shift)
  #expect(tools.colorValue == "#FF0000")
  #expect(tools.swatches == ["#FF0000"])
  try press(49, characters: " ", repeatKey: true)
  #expect(tools.frozenLoupe != nil)
  try press(49, characters: " ")
  #expect(tools.frozenLoupe == nil)
  tools.frozenLoupe = .zero
  tools.loupe = false
  #expect(tools.frozenLoupe == nil)
}
