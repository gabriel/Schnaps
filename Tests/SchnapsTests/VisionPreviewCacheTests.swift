import CoreGraphics
import MeasurementCore
import Testing
@testable import Schnaps

private func previewTestImage(red: CGFloat = 1) throws -> CGImage {
  let context = try #require(CGContext(
    data: nil, width: 16, height: 12, bitsPerComponent: 8, bytesPerRow: 64,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(red: red, green: 0.2, blue: 0.6, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
  context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
  context.fill(CGRect(x: 8, y: 0, width: 8, height: 12))
  return try #require(context.makeImage())
}

@MainActor
struct VisionPreviewCacheTests {
  @Test func redrawReusesRenderButCropModeSizeAndFrameInvalidateIt() throws {
    let cache = VisionPreviewCache()
    let source = try previewTestImage()
    let crop = CGRect(x: 0, y: 0, width: 8, height: 8)
    let first = try #require(cache.image(source: source, crop: crop, mode: .grayscale))
    #expect(cache.image(source: source, crop: crop, mode: .grayscale) === first)
    let shifted = try #require(cache.image(
      source: source, crop: crop.offsetBy(dx: 8, dy: 0), mode: .grayscale))
    #expect(shifted !== first)
    let firstPixels = try #require(PixelBuffer(image: first))
    let shiftedPixels = try #require(PixelBuffer(image: shifted))
    #expect(shiftedPixels.bytes != firstPixels.bytes)
    let blurred = try #require(cache.image(source: source, crop: crop, mode: .blur))
    #expect(blurred !== first)
    let resized = try #require(cache.image(
      source: source, crop: crop, mode: .grayscale, outputSize: CGSize(width: 4, height: 4)))
    #expect(resized.width == 4 && resized.height == 4)
    #expect(cache.image(source: source, crop: crop, mode: .grayscale,
                        outputSize: CGSize(width: 4, height: 4)) === resized)
    let newSource = try previewTestImage(red: 0)
    let refreshed = try #require(cache.image(source: newSource, crop: crop, mode: .grayscale))
    #expect(refreshed !== first)
    let refreshedPixels = try #require(PixelBuffer(image: refreshed))
    #expect(refreshedPixels.bytes != firstPixels.bytes)
    #expect(cache.byteCount == refreshed.bytesPerRow * refreshed.height)
    cache.prepare(for: nil)
    #expect(cache.byteCount == 0)
    #expect(cache.image(source: source, crop: crop, mode: .grayscale) !== first)
    cache.removeAll()
    #expect(cache.byteCount == 0)
  }

  @Test func cachedFiltersMatchUncachedPixelsForEveryMode() throws {
    let source = try previewTestImage()
    let cache = VisionPreviewCache()
    let crop = CGRect(x: 3, y: 2, width: 10, height: 7)
    for mode in VisionSimulation.allCases {
      let cropped = try #require(source.cropping(to: crop))
      let expected = try #require(PixelBuffer(image: VisionRenderer.apply(cropped, mode: mode)))
      let rendered = try #require(cache.image(source: source, crop: crop, mode: mode))
      let actual = try #require(PixelBuffer(image: rendered))
      #expect(actual.bytes == expected.bytes)
      #expect(cache.image(source: source, crop: crop, mode: mode) === rendered)
    }
  }

  @Test func memoryBudgetEvictsLeastRecentlyUsedRenderAndSkipsOversizedImages() throws {
    let source = try previewTestImage()
    let crop = CGRect(x: 0, y: 0, width: 8, height: 8)
    let reference = try #require(VisionPreviewCache().image(source: source, crop: crop, mode: .grayscale))
    let cost = reference.bytesPerRow * reference.height
    let cache = VisionPreviewCache(byteLimit: cost * 2)
    let first = try #require(cache.image(source: source, crop: crop, mode: .grayscale))
    let secondRect = crop.offsetBy(dx: 1, dy: 0)
    let second = try #require(cache.image(source: source, crop: secondRect, mode: .grayscale))
    #expect(cache.image(source: source, crop: crop, mode: .grayscale) === first)
    _ = cache.image(source: source, crop: crop.offsetBy(dx: 2, dy: 0), mode: .grayscale)
    #expect(cache.byteCount <= cost * 2)
    #expect(cache.image(source: source, crop: crop, mode: .grayscale) === first)
    #expect(cache.image(source: source, crop: secondRect, mode: .grayscale) !== second)
    let tinyCache = VisionPreviewCache(byteLimit: 1)
    #expect(tinyCache.image(source: source, crop: crop, mode: .grayscale) != nil)
    #expect(tinyCache.byteCount == 0)
  }

  @Test func retinaResamplingPreservesFractionalEdgeCrops() throws {
    let source = try previewTestImage()
    let result = try #require(VisionPreviewCache().image(
      source: source, crop: CGRect(x: 0, y: 0, width: 1, height: 8), mode: .normal,
      outputSize: CGSize(width: 0.5, height: 4)))
    #expect(result.width == 1 && result.height == 4)
  }
}

@MainActor
struct ScreenSnapshotConversionTests {
  @Test func backgroundConversionPreservesPixelsAndIndependentScales() async throws {
    let image = try previewTestImage()
    let converted = try #require(try await ScreenSnapshot.converting(
      image, logicalSize: CGSize(width: 8, height: 4)))
    #expect(converted.image === image)
    #expect(converted.scaleX == 2 && converted.scaleY == 3)
    let expected = try #require(PixelBuffer(image: image))
    #expect(converted.pixels.bytes == expected.bytes)
    #expect(converted.dimensions(at: CGPoint(x: 1, y: 1), tolerance: 0) != nil)
  }

  @Test func cancelledCaptureDoesNotReturnConvertedPixels() async throws {
    let image = try previewTestImage()
    let conversion = Task {
      try await ScreenSnapshot.converting(image, logicalSize: CGSize(width: 8, height: 4))
    }
    conversion.cancel()
    await #expect(throws: CancellationError.self) { try await conversion.value }
  }
}
