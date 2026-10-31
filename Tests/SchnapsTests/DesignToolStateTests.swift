import AppKit
import MeasurementCore
import Testing

@testable import Schnaps

@Test @MainActor func designMarkersValidateAndPersistWithoutSharingTestDefaults() throws {
  let name = "Schnaps.DesignTools.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  var first = DesignMarker(tool: .ruler, display: 0)
  first.width = 200
  var second = DesignMarker(tool: .ruler, display: 0)
  second.width = 100
  tools.markers = [first, second]
  tools.selectedID = first.id
  tools.synchronizeLength = true
  tools.synchronizeAngle = true
  tools.update {
    $0.width = 300
    $0.angle = 90
  }
  #expect(tools.markers.allSatisfy { $0.width == 300 && $0.angle == 90 })
  tools.update {
    $0.width = -.infinity
    $0.x = .nan
    $0.columns = 100000
    $0.opacity = 2
  }
  let validated = try #require(tools.selected)
  #expect(
    validated.width == 320 && validated.x == 100 && validated.columns == 64
      && validated.opacity == 1)
  let restored = DesignTools(defaults: defaults)
  #expect(restored.markers == tools.markers)
  #expect(!restored.visible && !restored.editing && !restored.loupe)
  tools.remove()
  #expect(tools.markers.count == 1)
}

@Test @MainActor func designImageExportHasBoundedRasterSize() throws {
  #expect(throws: TextCodecError.self) {
    try BrowserPreview.rasterSize(width: .infinity, height: 100)
  }
  #expect(throws: TextCodecError.self) {
    try BrowserPreview.rasterSize(width: 16000, height: 16000)
  }
  #expect(throws: TextCodecError.self) { try BrowserPreview.rasterSize(width: 100, height: 0) }
  let size = try BrowserPreview.rasterSize(width: 375, height: 2030)
  #expect(size.0 == 375 && size.1 == 2030)
}

@Test @MainActor func visionPreviewKeepsExtentAndMakesGrayChannelsEqual() throws {
  let context = try #require(
    CGContext(
      data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(NSColor.red.cgColor)
  context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
  let image = try #require(context.makeImage())
  for mode in VisionSimulation.allCases {
    let result = VisionRenderer.apply(image, mode: mode)
    #expect(result.width == 8 && result.height == 8)
    if mode == .grayscale {
      let pixels = try #require(PixelBuffer(image: result))
      #expect(abs(Int(pixels.bytes[0]) - Int(pixels.bytes[1])) <= 2)
      #expect(abs(Int(pixels.bytes[1]) - Int(pixels.bytes[2])) <= 2)
    }
  }
}
