import CoreGraphics
import Testing
@testable import MeasurementCore

private func fixture(width: Int = 80, height: Int = 60, boxes: [(CGRect, UInt8)]) throws -> PixelBuffer {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for (rect, value) in boxes {
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                for c in 0..<3 { bytes[(y * width + x) * 4 + c] = value }
            }
        }
    }
    return try #require(PixelBuffer(width: width, height: height, bytes: bytes))
}

@Test func measuresGapAndIndependentAxes() throws {
    let pixels = try fixture(boxes: [
        (CGRect(x: 5, y: 10, width: 15, height: 40), 0),
        (CGRect(x: 35, y: 10, width: 20, height: 40), 0)])
    let gap = try #require(pixels.dimensions(at: CGPoint(x: 27, y: 30)))
    #expect(gap.horizontal.start == CGPoint(x: 20, y: 30))
    #expect(gap.horizontal.end == CGPoint(x: 35, y: 30))
    #expect(gap.horizontal.length == 15)
    #expect(gap.vertical.length == 60)
    let object = try #require(pixels.dimensions(at: CGPoint(x: 10, y: 30)))
    #expect(object.horizontal.length == 15)
    #expect(object.vertical.length == 40)
}

@Test func findsOnePixelFeaturesAndClampsAtDisplayBoundary() throws {
    let pixels = try fixture(width: 10, height: 10, boxes: [(CGRect(x: 0, y: 0, width: 1, height: 10), 0)])
    let result = try #require(pixels.dimensions(at: .zero))
    #expect(result.horizontal.length == 1)
    #expect(result.vertical.length == 10)
    #expect(pixels.dimensions(at: CGPoint(x: 10, y: 0)) == nil)
    #expect(pixels.dimensions(at: CGPoint(x: -0.1, y: 0)) == nil)
}

@Test func looseDragSnapsToWholeObjectAndDisconnectedDetails() throws {
    let pixels = try fixture(boxes: [
        (CGRect(x: 20, y: 15, width: 10, height: 10), 30),
        (CGRect(x: 35, y: 20, width: 8, height: 15), 120)])
    #expect(pixels.objectBounds(in: CGRect(x: 10, y: 5, width: 45, height: 40))
            == CGRect(x: 20, y: 15, width: 23, height: 20))
    #expect(pixels.objectBounds(in: CGRect(x: 0, y: 40, width: 70, height: 15)) == nil)
}

@Test func higherToleranceCanExcludeShadows() throws {
    let pixels = try fixture(boxes: [
        (CGRect(x: 15, y: 10, width: 40, height: 35), 230),
        (CGRect(x: 20, y: 15, width: 30, height: 25), 30)])
    let region = CGRect(x: 5, y: 5, width: 60, height: 50)
    #expect(pixels.objectBounds(in: region, tolerance: 18) == CGRect(x: 15, y: 10, width: 40, height: 35))
    #expect(pixels.objectBounds(in: region, tolerance: 36) == CGRect(x: 20, y: 15, width: 30, height: 25))
}

@Test func snappedRegionClipsAndRejectsInvalidInput() throws {
    let pixels = try fixture(boxes: [(CGRect(x: 4, y: 3, width: 11, height: 7), 0)])
    #expect(pixels.objectBounds(in: CGRect(x: -10, y: -10, width: 100, height: 100))
            == CGRect(x: 4, y: 3, width: 11, height: 7))
    #expect(pixels.objectBounds(in: .null) == nil)
    #expect(pixels.objectBounds(in: .infinite) == nil)
    #expect(pixels.objectBounds(in: CGRect(x: 200, y: 0, width: 10, height: 10)) == nil)
}

@Test func dimensionsConvertToLogicalRetinaCoordinates() throws {
    let pixels = try fixture(boxes: [(CGRect(x: 20, y: 10, width: 30, height: 40), 0)])
    let dimensions = try #require(pixels.dimensions(at: CGPoint(x: 30, y: 20))).scaled(x: 0.5, y: 0.5)
    #expect(dimensions.horizontal.length == 15)
    #expect(dimensions.vertical.length == 20)
    #expect(dimensions.rect == CGRect(x: 10, y: 5, width: 15, height: 20))
}
