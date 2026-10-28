import Foundation
import CoreGraphics

import Testing
@testable import MeasurementCore

@Test func reverseDragAndClipping() {
    let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
    #expect(MeasurementGeometry.rectangle(from: CGPoint(x: 200, y: 150), to: CGPoint(x: -10, y: 20), within: bounds)
            == CGRect(x: 0, y: 20, width: 200, height: 130))
}

@Test func squareStaysSquareAtScreenEdge() {
    let rect = MeasurementGeometry.rectangle(from: CGPoint(x: 90, y: 20), to: CGPoint(x: 100, y: 90),
                                              within: CGRect(x: 0, y: 0, width: 100, height: 100), square: true)
    #expect(rect == CGRect(x: 90, y: 20, width: 10, height: 10))
}

@Test func retinaUnitsAndNudgeBounds() {
    let rect = CGRect(x: 10, y: 20, width: 100.5, height: 60)
    #expect(MeasurementGeometry.label(rect, scale: 2, unit: .pixels) == "201 × 120 px")
    #expect(MeasurementGeometry.label(rect, scale: 2, unit: .points) == "101 × 60 pt")
    let moved = MeasurementGeometry.translated(rect, dx: -100, dy: 999,
                                               within: CGRect(x: 0, y: 0, width: 300, height: 200))
    #expect(moved == CGRect(x: 0, y: 140, width: 100.5, height: 60))
}

@Test func detectsKnownRegionIncludingLastPixel() throws {
    var bytes = [UInt8](repeating: 255, count: 20 * 12 * 4)
    for y in 3..<9 {
        for x in 4..<15 {
            let offset = (y * 20 + x) * 4
            bytes[offset] = 40; bytes[offset + 1] = 50; bytes[offset + 2] = 60
        }
    }
    let buffer = try #require(PixelBuffer(width: 20, height: 12, bytes: bytes))
    #expect(buffer.edges(at: CGPoint(x: 8, y: 5)) == CGRect(x: 4, y: 3, width: 11, height: 6))
    #expect(buffer.edges(at: CGPoint(x: -1, y: 0)) == nil)
    #expect(buffer.edges(at: CGPoint(x: 20, y: 0)) == nil)
    #expect(buffer.edges(at: CGPoint(x: CGFloat.nan, y: 0)) == nil)
}

@Test func toleranceAndImageBoundary() throws {
    var bytes = [UInt8](repeating: 100, count: 4 * 3 * 4)
    for y in 0..<3 { for x in 2..<4 {
        for c in 0..<3 { bytes[(y * 4 + x) * 4 + c] = 120 }
    } }
    let buffer = try #require(PixelBuffer(width: 4, height: 3, bytes: bytes))
    #expect(buffer.edges(at: .zero, tolerance: 18) == CGRect(x: 0, y: 0, width: 2, height: 3))
    #expect(buffer.edges(at: .zero, tolerance: 25) == CGRect(x: 0, y: 0, width: 4, height: 3))
    #expect(PixelBuffer(width: 2, height: 2, bytes: [0]) == nil)
    #expect(PixelBuffer(width: Int.max, height: 2, bytes: []) == nil)
}

@Test func capturedImageKeepsTopLeftCoordinatesAndColorChannels() throws {
    let width = 12, height = 10
    var rgba = [UInt8](repeating: 255, count: width * height * 4)
    // An asymmetric red box near the top-left catches vertically inverted screenshots.
    for y in 1..<4 { for x in 2..<7 {
        let i = (y * width + x) * 4
        rgba[i] = 210; rgba[i + 1] = 30; rgba[i + 2] = 60
    } }
    let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
    let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let buffer = try #require(PixelBuffer(image: image))
    #expect(buffer.bytes[(1 * width + 2) * 4] == 210)
    #expect(buffer.edges(at: CGPoint(x: 3, y: 2)) == CGRect(x: 2, y: 1, width: 5, height: 3))
}
