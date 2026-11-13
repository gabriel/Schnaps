import CoreGraphics

/// A canvas-local LRU of rendered crops. Only the current source frame is retained.
@MainActor
final class VisionPreviewCache {
  private struct Key: Equatable {
    let crop: CGRect
    let mode: VisionSimulation
    let outputSize: CGSize?
  }
  private struct Entry {
    let key: Key
    let image: CGImage
    let cost: Int
  }
  private let byteLimit: Int
  private let entryLimit = 32
  private var source: CGImage?
  private var entries: [Entry] = []
  private(set) var byteCount = 0

  init(byteLimit: Int = 64 * 1024 * 1024) {
    self.byteLimit = max(0, byteLimit)
  }

  func prepare(for image: CGImage?) {
    guard source !== image else { return }
    removeAll()
    source = image
  }

  func removeAll() {
    entries.removeAll()
    byteCount = 0
    source = nil
  }

  func image(source: CGImage, crop: CGRect, mode: VisionSimulation,
             outputSize: CGSize? = nil) -> CGImage? {
    prepare(for: source)
    let key = Key(crop: crop, mode: mode, outputSize: outputSize)
    if let index = entries.firstIndex(where: { $0.key == key }) {
      let entry = entries.remove(at: index)
      entries.append(entry)
      return entry.image
    }
    guard let cropped = source.cropping(to: crop) else { return nil }
    var rendered = VisionRenderer.apply(cropped, mode: mode)
    if let size = outputSize, size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
       size.width * size.height <= 32_000_000,
       let context = CGContext(
         data: nil, width: max(1, Int(size.width)), height: max(1, Int(size.height)),
         bitsPerComponent: 8, bytesPerRow: 0,
         space: CGColorSpace(name: CGColorSpace.sRGB)!,
         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
      context.interpolationQuality = .high
      context.draw(rendered, in: CGRect(origin: .zero, size: size))
      rendered = context.makeImage() ?? rendered
    }
    // Normal crops can share the source's storage; account for that backing image too.
    let cost = max(rendered.bytesPerRow * rendered.height,
                   rendered === cropped ? source.bytesPerRow * source.height : 0)
    guard cost <= byteLimit else { return rendered }
    while !entries.isEmpty && (byteCount > byteLimit - cost || entries.count >= entryLimit) {
      byteCount -= entries.removeFirst().cost
    }
    entries.append(Entry(key: key, image: rendered, cost: cost))
    byteCount += cost
    return rendered
  }
}
