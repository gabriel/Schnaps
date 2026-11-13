import Foundation
import MeasurementCore

enum FindDimensionsLabel {
    /// Full pinned measurements are stored as consecutive horizontal/vertical spans.
    static func pair(_ horizontal: DimensionSpan, _ vertical: DimensionSpan) -> Dimensions? {
        guard horizontal.isHorizontal, !vertical.isHorizontal,
              horizontal.start.x <= vertical.start.x, vertical.start.x <= horizontal.end.x,
              vertical.start.y <= horizontal.start.y, horizontal.start.y <= vertical.end.y else { return nil }
        return Dimensions(horizontal: horizontal, vertical: vertical)
    }

    static func text(for rect: CGRect, presentation: MeasurementPresentation, scale: CGFloat) -> String {
        "\(presentation.value(rect.width, scale: scale)) × \(presentation.value(rect.height, scale: scale))"
    }

    /// Clamp the whole stack so the capsule always stays below the measurement.
    static func layout(at center: CGPoint, width: CGFloat, snapWidth: CGFloat?, in bounds: CGRect)
        -> (measurement: CGRect, snap: CGRect?) {
        let stack = frame(at: center, size: CGSize(width: max(width, snapWidth ?? 0),
                                                  height: snapWidth == nil ? 28 : 56), in: bounds)
        let measurementWidth = min(width, stack.width)
        let measurement = CGRect(x: stack.minX + (stack.width - measurementWidth) / 2,
                                 y: stack.minY, width: measurementWidth, height: 28)
        let snap = snapWidth.map { width in
            let width = min(width, stack.width)
            return CGRect(x: stack.midX - width / 2, y: measurement.maxY + 4, width: width, height: 24)
        }
        return (measurement, snap)
    }

    /// The center is the axes' intersection, not the midpoint of either span.
    /// Keep the label below and right of it, clamping only at the display edges.
    static func frame(at center: CGPoint, size: CGSize, in bounds: CGRect) -> CGRect {
        let available = bounds.insetBy(dx: 8, dy: 8)
        let size = CGSize(width: min(size.width, max(0, available.width)),
                          height: min(size.height, max(0, available.height)))
        return CGRect(x: max(available.minX, min(center.x + 10, available.maxX - size.width)),
                      y: max(available.minY, min(center.y + 10, available.maxY - size.height)),
                      width: size.width, height: size.height)
    }
}
