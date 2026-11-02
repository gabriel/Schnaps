import Foundation
import MeasurementCore

enum DimensionLabelPlacement {
    /// Coordinates use the measurement canvas's flipped (top-left) origin.
    static func frame(for span: DimensionSpan, size: CGSize, in bounds: CGRect,
                      avoiding labels: [CGRect]) -> CGRect {
        let available = bounds.insetBy(dx: 8, dy: 8)
        let size = CGSize(width: min(size.width, max(0, available.width)),
                          height: min(size.height, max(0, available.height)))
        let midpoint = CGPoint(x: (span.start.x + span.end.x) / 2,
                               y: (span.start.y + span.end.y) / 2)
        let gap: CGFloat = 10
        let origins = span.isHorizontal
            ? [CGPoint(x: midpoint.x - size.width / 2, y: midpoint.y + gap),
               CGPoint(x: midpoint.x - size.width / 2, y: midpoint.y - gap - size.height)]
            : [CGPoint(x: midpoint.x + gap, y: midpoint.y - size.height / 2),
               CGPoint(x: midpoint.x - gap - size.width, y: midpoint.y - size.height / 2)]
        func clamped(_ origin: CGPoint) -> CGRect {
            CGRect(x: max(available.minX, min(origin.x, available.maxX - size.width)),
                   y: max(available.minY, min(origin.y, available.maxY - size.height)),
                   width: size.width, height: size.height)
        }
        // Try both sides before moving along the span. Keep crowded labels local
        // rather than repeatedly shifting them toward the bottom of the display.
        let step = (span.isHorizontal ? size.width : size.height) + 4
        var candidates: [CGRect] = []
        for offset in [CGFloat(0), -step, step] {
            for origin in origins {
                let candidate = clamped(CGPoint(x: origin.x + (span.isHorizontal ? offset : 0),
                                                y: origin.y + (span.isHorizontal ? 0 : offset)))
                candidates.append(candidate)
            }
        }
        func clearsLine(_ rect: CGRect) -> Bool {
            span.isHorizontal
                ? rect.minY >= midpoint.y + gap || rect.maxY <= midpoint.y - gap
                : rect.minX >= midpoint.x + gap || rect.maxX <= midpoint.x - gap
        }
        return candidates.first(where: { candidate in
            clearsLine(candidate) && !labels.contains(where: { $0.insetBy(dx: -2, dy: -2).intersects(candidate) })
        }) ?? candidates.first(where: clearsLine) ?? clamped(origins[0])
    }
}
