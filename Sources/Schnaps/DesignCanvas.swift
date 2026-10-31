import AppKit
import CoreImage
import MeasurementCore

@MainActor
final class DesignCanvas: NSView {
  let display: NSScreen
  let state: DesignTools
  var snapshot: (() -> ScreenSnapshot?)?
  private var dragStart: CGPoint?
  private var original: DesignMarker?
  private var originals: [DesignMarker] = []
  private var draggingEnd = false, resizing = false
  private var imageCache: [String: NSImage] = [:]
  init(frame: CGRect, screen: NSScreen, state: DesignTools) {
    display = screen
    self.state = state
    super.init(frame: frame)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  private var displayID: UInt32 { DesignTools.displayID(display) }
  private var pointer: CGPoint {
    let p = NSEvent.mouseLocation
    return CGPoint(x: p.x - display.frame.minX, y: display.frame.maxY - p.y)
  }
  private func line(_ a: CGPoint, _ b: CGPoint, color: NSColor, width: CGFloat = 1) {
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = width
    path.move(to: a)
    path.line(to: b)
    path.stroke()
  }
  private func caption(_ text: String, at point: CGPoint) {
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
      .foregroundColor: NSColor.white,
    ]
    let size = (text as NSString).size(withAttributes: attrs)
    let rect = CGRect(
      x: min(bounds.maxX - size.width - 12, max(0, point.x)),
      y: min(bounds.maxY - size.height - 8, max(0, point.y)), width: size.width + 10,
      height: size.height + 6)
    NSColor.black.withAlphaComponent(0.86).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
    (text as NSString).draw(at: CGPoint(x: rect.minX + 5, y: rect.minY + 3), withAttributes: attrs)
  }
  private func number(_ value: Double) -> String { String(format: "%.1f", value) }
  private func drawImage(_ image: NSImage, in rect: CGRect, opacity: Double = 1) {
    image.draw(
      in: rect, from: .zero, operation: .sourceOver, fraction: opacity, respectFlipped: true,
      hints: [.interpolation: NSImageInterpolation.none])
  }
  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.setFill()
    dirtyRect.fill(using: .copy)
    guard state.visible else { return }
    let active = state.markers.filter { $0.display == displayID }
    for marker in active { draw(marker) }
    let point = pointer
    if state.crosshair, bounds.contains(point) {
      var color = MeasurementPreferences.color(PreferenceKey.guideColor)
      if UserDefaults.standard.bool(forKey: PreferenceKey.autoContrast), let pixel = sample(point) {
        color = pixel.luminance > 0.45 ? .black : .white
      }
      line(
        CGPoint(x: 0, y: point.y), CGPoint(x: bounds.width, y: point.y), color: color,
        width: state.lineWidth)
      line(
        CGPoint(x: point.x, y: 0), CGPoint(x: point.x, y: bounds.height), color: color,
        width: state.lineWidth)
      let origin = state.relativeOrigin ?? .zero
      caption(
        "x \(number(point.x-origin.x))  y \(number(point.y-origin.y)) pt",
        at: CGPoint(x: point.x + 14, y: point.y + 14))
    }
    if state.loupe {
      let frozen =
        state.frozenLoupe.map {
          CGPoint(x: $0.x - display.frame.minX, y: display.frame.maxY - $0.y)
        } ?? point
      if bounds.contains(frozen) { drawLoupe(at: frozen) }
    }
  }
  private func draw(_ marker: DesignMarker) {
    let selected = state.editing && marker.id == state.selectedID
    let color = (NSColor(schnapsHex: marker.color) ?? .systemBlue).withAlphaComponent(
      marker.opacity)
    if marker.tool == .ruler {
      drawRuler(marker, color: color)
      return
    }
    if marker.tool == .guides {
      let a = marker.vertical ? CGPoint(x: marker.x, y: 0) : CGPoint(x: 0, y: marker.y)
      let b =
        marker.vertical
        ? CGPoint(x: marker.x, y: bounds.height) : CGPoint(x: bounds.width, y: marker.y)
      line(a, b, color: color, width: selected ? 2 : 1)
      caption(
        "\(marker.vertical ? "x" : "y") \(number(marker.vertical ? marker.x : marker.y)) pt",
        at: CGPoint(x: marker.vertical ? marker.x + 4 : 8, y: marker.vertical ? 8 : marker.y + 4))
      let peers = state.markers.filter {
        $0.display == marker.display && $0.tool == .guides && $0.vertical == marker.vertical
          && ($0.vertical ? $0.x > marker.x : $0.y > marker.y)
      }
      if let next = peers.min(by: {
        (marker.vertical ? $0.x : $0.y) < (marker.vertical ? $1.x : $1.y)
      }) {
        let distance = marker.vertical ? next.x - marker.x : next.y - marker.y
        caption(
          "\(number(distance)) pt",
          at: CGPoint(
            x: marker.vertical ? (next.x + marker.x) / 2 : 50,
            y: marker.vertical ? 40 : (next.y + marker.y) / 2))
      }
      return
    }
    if let name = marker.imageName, name == URL(fileURLWithPath: name).lastPathComponent {
      if imageCache[name] == nil {
        imageCache[name] = NSImage(contentsOf: DesignTools.imageFolder.appendingPathComponent(name))
      }
      if let image = imageCache[name] { drawImage(image, in: marker.rect, opacity: marker.opacity) }
    }
    if marker.tool == .screens, state.vision != .normal || state.retinaPreview,
      let frame = snapshot?()
    {
      let region = marker.rect.intersection(
        CGRect(
          x: 0, y: 0, width: Double(frame.image.width) / frame.scaleX,
          height: Double(frame.image.height) / frame.scaleY))
      if !region.isEmpty, !region.isNull,
        let crop = frame.image.cropping(
          to: CGRect(
            x: region.minX * frame.scaleX, y: region.minY * frame.scaleY,
            width: region.width * frame.scaleX, height: region.height * frame.scaleY))
      {
        var filtered = VisionRenderer.apply(crop, mode: state.vision)
        if state.retinaPreview, region.width * region.height <= 32_000_000,
          let context = CGContext(
            data: nil, width: max(1, Int(region.width)), height: max(1, Int(region.height)),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        {
          context.interpolationQuality = .high
          context.draw(filtered, in: CGRect(origin: .zero, size: region.size))
          filtered = context.makeImage() ?? filtered
        }
        drawImage(NSImage(cgImage: filtered, size: region.size), in: region)
      }
    }
    color.setStroke()
    let border = NSBezierPath(rect: marker.rect)
    border.lineWidth = selected ? 2 : 1
    border.stroke()
    if marker.tool == .overlay || marker.columns > 1 || marker.rows > 1 {
      let column = DesignGeometry.columnWidth(
        width: marker.width, columns: marker.columns, margin: marker.margin, gutter: marker.gutter)
      if column > 0 {
        for index in 0..<marker.columns {
          let rect = CGRect(
            x: marker.x + marker.margin + Double(index) * (column + marker.gutter), y: marker.y,
            width: column, height: marker.height)
          color.withAlphaComponent(marker.opacity * 0.12).setFill()
          NSBezierPath(rect: rect).fill()
          line(rect.origin, CGPoint(x: rect.minX, y: rect.maxY), color: color)
          line(
            CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), color: color)
        }
      }
      for row in 1..<marker.rows {
        let y = marker.y + Double(row) * marker.height / Double(marker.rows)
        line(CGPoint(x: marker.x, y: y), CGPoint(x: marker.x + marker.width, y: y), color: color)
      }
    }
    if marker.spacing >= 2 {
      for y in stride(
        from: marker.y + marker.spacing, to: marker.y + marker.height, by: marker.spacing)
      {
        line(
          CGPoint(x: marker.x, y: y), CGPoint(x: marker.x + marker.width, y: y),
          color: color.withAlphaComponent(marker.opacity * 0.3))
      }
    }
    if marker.marks {
      line(
        CGPoint(x: marker.rect.midX - 8, y: marker.rect.midY),
        CGPoint(x: marker.rect.midX + 8, y: marker.rect.midY), color: color)
      line(
        CGPoint(x: marker.rect.midX, y: marker.rect.midY - 8),
        CGPoint(x: marker.rect.midX, y: marker.rect.midY + 8), color: color)
    }
    if marker.tool == .screens {
      let top = min(marker.height, marker.topInset)
      let bottom = min(marker.height - top, marker.bottomInset + marker.keyboardHeight)
      let left = min(marker.width, marker.leftInset)
      let right = min(marker.width - left, marker.rightInset)
      color.withAlphaComponent(0.16).setFill()
      for rect in [
        CGRect(x: marker.x, y: marker.y, width: marker.width, height: top),
        CGRect(x: marker.x, y: marker.rect.maxY - bottom, width: marker.width, height: bottom),
        CGRect(x: marker.x, y: marker.y + top, width: left, height: marker.height - top - bottom),
        CGRect(
          x: marker.rect.maxX - right, y: marker.y + top, width: right,
          height: marker.height - top - bottom),
      ] { NSBezierPath(rect: rect).fill() }
      caption(
        "Usable \(number(marker.width-left-right)) × \(number(marker.height-top-bottom)) pt",
        at: CGPoint(x: marker.x + left + 4, y: marker.y + top + 4))
    }
    if marker.safeAreas {
      for inset in [0.05, 0.1] {
        let safe = marker.rect.insetBy(dx: marker.width * inset, dy: marker.height * inset)
        let path = NSBezierPath(rect: safe)
        path.setLineDash([4, 4], count: 2, phase: 0)
        path.stroke()
      }
    }
    caption(
      "\(number(marker.width)) × \(number(marker.height)) pt · \(number(marker.x)), \(number(marker.y)) · \(number(marker.width/marker.height)):1",
      at: CGPoint(x: marker.x, y: marker.y - 24))
    if selected {
      NSColor.controlAccentColor.setFill()
      for p in [marker.rect.origin, CGPoint(x: marker.rect.maxX, y: marker.rect.maxY)] {
        NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)).fill()
      }
    }
  }
  private func drawRuler(_ marker: DesignMarker, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: marker.x, yBy: marker.y)
    transform.rotate(byDegrees: marker.angle)
    transform.concat()
    color.withAlphaComponent(0.10).setFill()
    NSBezierPath(rect: CGRect(x: 0, y: -18, width: marker.width, height: 36)).fill()
    line(.zero, CGPoint(x: marker.width, y: 0), color: color)
    let pixels = UserDefaults.standard.string(forKey: PreferenceKey.unit) == "px"
    let unit = pixels ? display.backingScaleFactor : 1
    let units = marker.width * unit / marker.scale
    let interval = max(1, pow(10, floor(log10(max(1, units / 30)))))
    for value in stride(from: 0.0, through: units, by: interval) {
      let x = value * marker.scale / unit
      let major = Int((value / interval).rounded()) % 5 == 0
      line(CGPoint(x: x, y: major ? -12 : -6), CGPoint(x: x, y: major ? 12 : 6), color: color)
    }
    if marker.marks {
      for fraction in [0.25, 1.0 / 3, 0.5, 2.0 / 3, 0.61803398875, 0.75] {
        let x = marker.width * fraction
        line(CGPoint(x: x, y: -18), CGPoint(x: x, y: 18), color: color.withAlphaComponent(0.5))
      }
    }
    if marker.calipers {
      for x in [0.0, marker.width] {
        line(CGPoint(x: x, y: -70), CGPoint(x: x, y: 70), color: color)
      }
    }
    if marker.square {
      line(.zero, CGPoint(x: 0, y: marker.height), color: color)
      line(
        CGPoint(x: 0, y: marker.height), CGPoint(x: marker.width, y: marker.height), color: color)
    }
    NSGraphicsContext.restoreGraphicsState()
    caption(
      "\(number(units)) \(pixels ? "px" : "pt") · \(number(marker.angle))° · Δ \(number(marker.end.x-marker.x)), \(number(marker.end.y-marker.y))",
      at: CGPoint(x: marker.x, y: marker.y + 22))
  }
  private func sample(_ point: CGPoint) -> InspectorColor? {
    guard let frame = snapshot?() else { return nil }
    let x = floor(point.x * frame.scaleX)
    let y = floor(point.y * frame.scaleY)
    guard x >= 0, y >= 0, x < Double(frame.image.width), y < Double(frame.image.height),
      let pixel = frame.image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))
    else { return nil }
    var bytes = [UInt8](repeating: 0, count: 4)
    let success = bytes.withUnsafeMutableBytes { raw in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
      return true
    }
    guard success else { return nil }
    return InspectorColor(
      red: Double(bytes[0]) / 255, green: Double(bytes[1]) / 255, blue: Double(bytes[2]) / 255)
  }
  private func drawLoupe(at point: CGPoint) {
    guard let frame = snapshot?() else {
      caption("Waiting for screen pixels…", at: point)
      return
    }
    let size = 180.0
    let zoom = max(2, min(32, state.zoom))
    let pixels = size / zoom
    let sampleRect = CGRect(
      x: point.x * frame.scaleX - pixels / 2, y: point.y * frame.scaleY - pixels / 2, width: pixels,
      height: pixels
    ).integral
    let cropRect = sampleRect.intersection(
      CGRect(x: 0, y: 0, width: frame.image.width, height: frame.image.height))
    guard let crop = frame.image.cropping(to: cropRect) else { return }
    let rect = CGRect(
      x: min(bounds.width - size - 8, max(8, point.x + 24)),
      y: min(bounds.height - size - 58, max(8, point.y + 24)), width: size, height: size)
    NSColor.windowBackgroundColor.setFill()
    NSBezierPath(rect: rect.insetBy(dx: -2, dy: -2)).fill()
    let target = CGRect(
      x: rect.minX + (cropRect.minX - sampleRect.minX) * zoom,
      y: rect.minY + (cropRect.minY - sampleRect.minY) * zoom, width: cropRect.width * zoom,
      height: cropRect.height * zoom)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: rect).addClip()
    drawImage(
      NSImage(cgImage: VisionRenderer.apply(crop, mode: state.vision), size: target.size),
      in: target)
    if state.pixelGrid && zoom >= 6 {
      let step = zoom
      for index in 0...crop.width {
        let x = target.minX + Double(index) * step
        line(
          CGPoint(x: x, y: target.minY), CGPoint(x: x, y: target.maxY),
          color: .black.withAlphaComponent(0.2))
      }
      for index in 0...crop.height {
        let y = target.minY + Double(index) * zoom
        line(
          CGPoint(x: target.minX, y: y), CGPoint(x: target.maxX, y: y),
          color: .black.withAlphaComponent(0.2))
      }
    }
    NSGraphicsContext.restoreGraphicsState()
    let centerX = rect.minX + (point.x * frame.scaleX - sampleRect.minX) * zoom
    let centerY = rect.minY + (point.y * frame.scaleY - sampleRect.minY) * zoom
    line(CGPoint(x: centerX, y: rect.minY), CGPoint(x: centerX, y: rect.maxY), color: .white)
    line(CGPoint(x: rect.minX, y: centerY), CGPoint(x: rect.maxX, y: centerY), color: .white)
    if let color = sample(point) {
      let value = color.formatted(state.colorFormat)
      caption(value, at: CGPoint(x: rect.minX, y: rect.maxY + 5))
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.state.colorSample = color
        if self.state.colorValue != value { self.state.colorValue = value }
        self.state.referenceColor = color.formatted(self.state.referenceFormat)
        if let reference = self.state.contrastSample {
          self.state.contrast = String(format: "%.2f:1", color.contrast(with: reference))
        }
      }
    }
  }
  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let candidates = state.markers.filter { $0.display == displayID && !$0.locked }
    guard
      let selected = candidates.reversed().first(where: { m in
        if m.tool == .ruler {
          return DesignGeometry.distance(point, toSegmentFrom: CGPoint(x: m.x, y: m.y), to: m.end)
            < 20
        }
        if m.tool == .guides { return abs(m.vertical ? point.x - m.x : point.y - m.y) < 10 }
        return m.rect.insetBy(dx: -8, dy: -8).contains(point)
      })
    else {
      if state.crosshair { state.relativeOrigin = point }
      return
    }
    state.selectedID = selected.id
    if event.modifierFlags.contains(.option) { state.duplicate() }
    guard let marker = state.selected else { return }
    original = marker
    originals = state.markers
    dragStart = point
    draggingEnd =
      marker.tool == .ruler && hypot(point.x - marker.end.x, point.y - marker.end.y) < 20
    resizing =
      marker.tool != .ruler && marker.tool != .guides
      && hypot(point.x - marker.rect.maxX, point.y - marker.rect.maxY) < 20
  }
  override func mouseDragged(with event: NSEvent) {
    guard let start = dragStart, let marker = original else { return }
    var point = convert(event.locationInWindow, from: nil)
    if event.modifierFlags.contains(.control), let frame = snapshot?(),
      let edges = frame.dimensions(
        at: point,
        tolerance: MeasurementPreferences.threshold(MeasurementPreferences.selectedTolerance))
    {
      for x in [edges.horizontal.start.x, edges.horizontal.end.x] where abs(x - point.x) < 10 {
        point.x = x
      }
      for y in [edges.vertical.start.y, edges.vertical.end.y] where abs(y - point.y) < 10 {
        point.y = y
      }
    }
    let dx = point.x - start.x
    let dy = point.y - start.y
    if draggingEnd {
      state.update { item in
        item.width = hypot(point.x - marker.x, point.y - marker.y)
        item.angle = atan2(point.y - marker.y, point.x - marker.x) * 180 / .pi
        if event.modifierFlags.contains(.shift) {
          item.angle = DesignGeometry.snapped(item.angle, step: 45)
        }
      }
    } else if resizing {
      state.update {
        $0.width = point.x - marker.x
        $0.height = point.y - marker.y
      }
    } else {
      state.markers = originals.map { item in
        guard
          item.id == marker.id
            || (state.linked && item.display == marker.display && item.tool == marker.tool
              && !item.locked)
        else { return item }
        var item = item
        item.x += dx
        item.y += dy
        item.validate()
        return item
      }
    }
  }
  override func mouseUp(with event: NSEvent) {
    dragStart = nil
    original = nil
    originals = []
  }
  override func keyDown(with event: NSEvent) {
    guard state.editing else {
      super.keyDown(with: event)
      return
    }
    let step = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
    switch event.keyCode {
    case 53: state.editing = false
    case 123, 124, 125, 126:
      if event.modifierFlags.contains(.option), state.selected?.tool == .ruler {
        let rotation =
          event.modifierFlags.contains(.control)
          ? 0.1 : event.modifierFlags.contains(.shift) ? 5.0 : 1.0
        state.update {
          $0.angle += (event.keyCode == 123 || event.keyCode == 125) ? -rotation : rotation
        }
      } else {
        state.update { m in
          if !m.locked {
            m.x += event.keyCode == 123 ? -step : event.keyCode == 124 ? step : 0
            m.y += event.keyCode == 126 ? -step : event.keyCode == 125 ? step : 0
          }
        }
      }
    case 51, 117: state.remove()
    default:
      switch event.charactersIgnoringModifiers?.lowercased() {
      case " ":
        if state.loupe {
          state.frozenLoupe = state.frozenLoupe == nil ? NSEvent.mouseLocation : nil
        }
      case "o": state.relativeOrigin = pointer
      case "r": state.relativeOrigin = nil
      case "c":
        if state.loupe {
          if event.modifierFlags.contains(.shift) { state.saveColor() } else { state.copyColor() }
        } else {
          state.capture?(true)
        }
      case "p": state.capture?(false)
      case "h", "v", "f":
        let key = event.charactersIgnoringModifiers!.lowercased()
        let list = state.markers.filter {
          $0.display == displayID
            && (key == "f" ? $0.tool == .frames : $0.tool == .guides && $0.vertical == (key == "v"))
        }
        if !list.isEmpty {
          let next =
            (list.firstIndex(where: { $0.id == state.selectedID }).map { $0 + 1 } ?? 0) % list.count
          state.selectedID = list[next].id
        }
      default: super.keyDown(with: event)
      }
    }
  }
}
