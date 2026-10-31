import AppKit
import CoreImage

@MainActor
enum VisionRenderer {
  private static let context = CIContext(options: [
    .cacheIntermediates: false, .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
  ])
  static func apply(_ image: CGImage, mode: VisionSimulation) -> CGImage {
    guard mode != .normal else { return image }
    var source = CIImage(cgImage: image)
    let matrix: [[Double]]
    switch mode {
    case .protanopia: matrix = [[0.567, 0.433, 0], [0.558, 0.442, 0], [0, 0.242, 0.758]]
    case .deuteranopia: matrix = [[0.625, 0.375, 0], [0.7, 0.3, 0], [0, 0.3, 0.7]]
    case .tritanopia: matrix = [[0.95, 0.05, 0], [0, 0.433, 0.567], [0, 0.475, 0.525]]
    case .grayscale: matrix = Array(repeating: [0.2126, 0.7152, 0.0722], count: 3)
    case .blur:
      matrix = []
      source = source.clampedToExtent().applyingFilter(
        "CIGaussianBlur", parameters: [kCIInputRadiusKey: 3]
      ).cropped(to: source.extent)
    case .normal: matrix = []
    }
    if !matrix.isEmpty {
      source = source.applyingFilter(
        "CIColorMatrix",
        parameters: [
          "inputRVector": CIVector(x: matrix[0][0], y: matrix[0][1], z: matrix[0][2], w: 0),
          "inputGVector": CIVector(x: matrix[1][0], y: matrix[1][1], z: matrix[1][2], w: 0),
          "inputBVector": CIVector(x: matrix[2][0], y: matrix[2][1], z: matrix[2][2], w: 0),
        ])
    }
    return context.createCGImage(source, from: source.extent) ?? image
  }
}
