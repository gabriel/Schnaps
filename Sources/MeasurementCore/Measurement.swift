import Foundation
import CoreGraphics


public enum MeasurementUnit: String, CaseIterable, Sendable {
    case points = "pt"
    case pixels = "px"
}

public enum MeasurementGeometry {
    public static func rectangle(from start: CGPoint, to end: CGPoint, within bounds: CGRect,
                                 square: Bool = false) -> CGRect {
        var delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        if square {
            let side = min(max(abs(delta.x), abs(delta.y)),
                           delta.x < 0 ? start.x - bounds.minX : bounds.maxX - start.x,
                           delta.y < 0 ? start.y - bounds.minY : bounds.maxY - start.y)
            delta = CGPoint(x: delta.x < 0 ? -side : side, y: delta.y < 0 ? -side : side)
        }
        return CGRect(x: min(start.x, start.x + delta.x), y: min(start.y, start.y + delta.y),
                      width: abs(delta.x), height: abs(delta.y)).intersection(bounds)
    }

    public static func label(_ rect: CGRect, scale: CGFloat, unit: MeasurementUnit) -> String {
        let factor = unit == .pixels ? scale : 1
        return "\(Int((rect.width * factor).rounded())) × \(Int((rect.height * factor).rounded())) \(unit.rawValue)"
    }

    public static func translated(_ rect: CGRect, dx: CGFloat, dy: CGFloat, within bounds: CGRect) -> CGRect {
        CGRect(x: min(max(rect.minX + dx, bounds.minX), bounds.maxX - rect.width),
               y: min(max(rect.minY + dy, bounds.minY), bounds.maxY - rect.height),
               width: rect.width, height: rect.height)
    }
}

/// Top-left-origin, tightly packed RGBA pixels. Independent of AppKit and capture APIs.
public struct PixelBuffer: Sendable {
    public let width: Int
    public let height: Int
    public let bytes: [UInt8]

    public init?(width: Int, height: Int, bytes: [UInt8]) {
        guard width > 0, height > 0,
              width <= Int.max / height / 4, bytes.count == width * height * 4 else { return nil }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    public init?(image: CGImage) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = data.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: image.width, height: image.height, bytes: data)
    }

    /// Finds the continuous color run through the cursor on both axes.
    public func edges(at point: CGPoint, tolerance: Int = 18) -> CGRect? {
        guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.y >= 0,
              point.x < CGFloat(width), point.y < CGFloat(height) else { return nil }
        let x = Int(point.x), y = Int(point.y)
        let threshold = max(0, min(255, tolerance))
        let seed = (y * width + x) * 4
        func matches(_ px: Int, _ py: Int) -> Bool {
            let offset = (py * width + px) * 4
            return (0..<3).allSatisfy { abs(Int(bytes[offset + $0]) - Int(bytes[seed + $0])) <= threshold }
        }
        var left = x, right = x, top = y, bottom = y
        while left > 0 && matches(left - 1, y) { left -= 1 }
        while right + 1 < width && matches(right + 1, y) { right += 1 }
        while top > 0 && matches(x, top - 1) { top -= 1 }
        while bottom + 1 < height && matches(x, bottom + 1) { bottom += 1 }
        guard right > left, bottom > top else { return nil }
        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }
}
