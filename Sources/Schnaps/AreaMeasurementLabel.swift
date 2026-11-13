import Foundation

/// Shared by manual areas and areas selected with Find Dimensions.
enum AreaMeasurementLabel {
    static func frame(for area: CGRect, size: CGSize, in bounds: CGRect, avoiding labels: [CGRect]) -> CGRect {
        let available = bounds.insetBy(dx: 8, dy: 8)
        let size = CGSize(width: min(size.width, max(0, available.width)),
                          height: min(size.height, max(0, available.height)))
        var position = CGPoint(x: area.midX, y: area.maxY + 10)
        if position.y + size.height > available.maxY { position.y = area.minY - size.height - 6 }
        func clamped() -> CGRect {
            CGRect(x: min(max(available.minX, position.x - size.width / 2), available.maxX - size.width),
                   y: min(max(available.minY, position.y), available.maxY - size.height),
                   width: size.width, height: size.height)
        }
        var label = clamped()
        for _ in 0..<20 {
            guard labels.contains(where: { $0.insetBy(dx: -3, dy: -3).intersects(label) }) else { break }
            position.y = label.minY + size.height + 4
            if position.y + size.height > available.maxY {
                position.y = available.minY
                position.x += 40
            }
            label = clamped()
        }
        return label
    }
}
