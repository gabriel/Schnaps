import Foundation

/// Coordinates in the captured image, whose origin is the display's top-left.
struct LoupeSelection {
  let pixel: CGPoint
  let scaleX: CGFloat
  let scaleY: CGFloat
  let imageSize: CGSize

  init(point: CGPoint, scaleX: CGFloat, scaleY: CGFloat, imageSize: CGSize) {
    self.scaleX = scaleX
    self.scaleY = scaleY
    self.imageSize = imageSize
    pixel = CGPoint(
      x: min(imageSize.width - 1, max(0, floor(point.x * scaleX))),
      y: min(imageSize.height - 1, max(0, floor(point.y * scaleY))))
  }

  func sourceRect(size: CGFloat, zoom: CGFloat) -> CGRect {
    let radius = ceil(size / zoom / 2)
    return CGRect(x: pixel.x - radius, y: pixel.y - radius,
                  width: radius * 2 + 1, height: radius * 2 + 1)
  }

  /// Return a logical point at the center of the destination physical pixel.
  func moved(dx: CGFloat, dy: CGFloat) -> CGPoint {
    CGPoint(
      x: (min(imageSize.width - 1, max(0, pixel.x + dx)) + 0.5) / scaleX,
      y: (min(imageSize.height - 1, max(0, pixel.y + dy)) + 0.5) / scaleY)
  }
}
