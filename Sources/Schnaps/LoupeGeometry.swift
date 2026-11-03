import CoreGraphics

/// Places the loupe away from the pointer, flipping sides near display edges.
enum LoupeGeometry {
  static func panel(at point: CGPoint, in bounds: CGRect, size: CGFloat) -> CGRect {
    let margin: CGFloat = 8
    let offset: CGFloat = 24
    let captionHeight: CGFloat = 30
    let x = point.x + offset + size <= bounds.maxX - margin
      ? point.x + offset : point.x - offset - size
    let y = point.y + offset + size + captionHeight <= bounds.maxY - margin
      ? point.y + offset : point.y - offset - size - captionHeight
    return CGRect(
      x: max(bounds.minX + margin, min(x, bounds.maxX - size - margin)),
      y: max(bounds.minY + margin, min(y, bounds.maxY - size - captionHeight - margin)),
      width: size, height: size)
  }
}
