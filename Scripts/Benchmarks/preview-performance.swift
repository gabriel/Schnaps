import AppKit
import Darwin
import MeasurementCore

private func cpuSeconds() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
    + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}
private func now() -> Double { ProcessInfo.processInfo.systemUptime }
private func percentile(_ values: [Double], _ fraction: Double) -> Double {
  let sorted = values.sorted()
  return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction))]
}
private func context(_ width: Int, _ height: Int) -> CGContext {
  CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
private func scene(_ width: Int, _ height: Int, alternate: Bool = false) -> CGImage {
  let ctx = context(width, height)
  ctx.setFillColor(gray: alternate ? 0.9 : 0.95, alpha: 1)
  ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
  for row in 0..<30 {
    for column in 0..<40 {
      let seed = (row * 17 + column * 29 + (alternate ? 11 : 0)) % 255
      ctx.setFillColor(red: CGFloat(seed) / 255, green: CGFloat((seed * 3) % 255) / 255,
                       blue: CGFloat((seed * 7) % 255) / 255, alpha: 1)
      ctx.fill(CGRect(x: column * width / 40, y: row * height / 30,
                      width: max(1, width / 40 - 5), height: max(1, height / 30 - 5)))
    }
  }
  return ctx.makeImage()!
}

@MainActor
private func uncached(_ source: CGImage, crop: CGRect, mode: VisionSimulation,
                      outputSize: CGSize?) -> CGImage {
  // The crop/filter/resampling path from main's DesignCanvas.draw and drawLoupe.
  var filtered = VisionRenderer.apply(source.cropping(to: crop)!, mode: mode)
  if let size = outputSize, size.width * size.height <= 32_000_000 {
    let ctx = context(max(1, Int(size.width)), max(1, Int(size.height)))
    ctx.interpolationQuality = .high
    ctx.draw(filtered, in: CGRect(origin: .zero, size: size))
    filtered = ctx.makeImage() ?? filtered
  }
  return filtered
}

@main
struct PreviewPerformance {
  @MainActor
  private static func converted(_ image: CGImage, size: CGSize) async throws -> ScreenSnapshot? {
    #if CACHED
    return try await ScreenSnapshot.converting(image, logicalSize: size)
    #else
    // main performs this synchronous conversion on MainActor after captureImage returns.
    return autoreleasepool {
      PixelBuffer(image: image).map {
        ScreenSnapshot(image: image, pixels: $0,
                       scaleX: CGFloat(image.width) / size.width,
                       scaleY: CGFloat(image.height) / size.height)
      }
    }
    #endif
  }

  @MainActor
  static func main() async throws {
    var results: [[String: Any]] = []
    let sources = [scene(3840, 2160), scene(3840, 2160, alternate: true)]
    let cases: [(String, CGRect, VisionSimulation, CGSize?, Bool)] = [
      ("screen-grayscale", CGRect(x: 100, y: 100, width: 1200, height: 1600), .grayscale, nil, false),
      ("screen-blur-retina", CGRect(x: 100, y: 100, width: 1200, height: 1600), .blur, CGSize(width: 600, height: 800), false),
      ("loupe-grayscale", CGRect(x: 100, y: 100, width: 24, height: 24), .grayscale, nil, false),
      ("screen-cache-misses", CGRect(x: 100, y: 100, width: 1200, height: 1600), .grayscale, nil, true)
    ]
    for (name, crop, mode, size, misses) in cases {
      let destinationSize = size ?? crop.size
      let destination = context(Int(destinationSize.width), Int(destinationSize.height))
      let target = CGRect(origin: .zero, size: destinationSize)
      // Warm Core Image compilation/GPU resources outside the measured section.
      for _ in 0..<8 { destination.draw(uncached(sources[0], crop: crop, mode: mode, outputSize: size), in: target) }
      #if CACHED
      let cache = VisionPreviewCache()
      #endif
      let wallStart = now(), cpuStart = cpuSeconds()
      let redraws = 120
      for redraw in 0..<redraws {
        autoreleasepool {
          // Simulate 30 redraws and four captures per second. Distinct captures have distinct identities.
          let index = misses ? redraw % 2 : (redraw * 4 / 30) % 2
          #if CACHED
          let image = cache.image(source: sources[index], crop: crop, mode: mode, outputSize: size)!
          #else
          let image = uncached(sources[index], crop: crop, mode: mode, outputSize: size)
          #endif
          // Force image realization and include the common paint cost in both variants.
          destination.draw(image, in: target)
        }
      }
      destination.flush()
      results.append(["workload": name, "redraws": redraws,
                      "cpu_ms": (cpuSeconds() - cpuStart) * 1000,
                      "wall_ms": (now() - wallStart) * 1000])
    }
    for (width, height) in [(3840, 2160), (5120, 2880)] {
      let image = scene(width, height)
      let size = CGSize(width: width / 2, height: height / 2)
      // Warm allocation/color conversion outside measurement.
      _ = PixelBuffer(image: image)
      // A separate throughput block excludes heartbeat/probe CPU and idle time.
      var throughputSnapshot: ScreenSnapshot?
      var throughputChecksum: UInt64 = 0
      let throughputWall = now(), throughputCPU = cpuSeconds()
      for frame in 0..<60 {
        throughputSnapshot = try await converted(image, size: size)
        throughputChecksum += UInt64(throughputSnapshot!.pixels.bytes[frame * 4])
      }
      withExtendedLifetime(throughputSnapshot) {}
      results.append(["workload": "conversion-cpu-\(width)x\(height)", "frames": 60,
                      "cpu_ms": (cpuSeconds() - throughputCPU) * 1000,
                      "wall_ms": (now() - throughputWall) * 1000, "checksum": throughputChecksum])
      throughputSnapshot = nil
      let duration = 3.0
      let start = now()
      let heartbeat = Task.detached(priority: .userInitiated) { () -> [Double] in
        var delays: [Double] = []
        while now() < start + duration {
          try? await Task.sleep(for: .milliseconds(2))
          let requested = now()
          let serviced = await MainActor.run { now() }
          delays.append((serviced - requested) * 1000)
        }
        return delays
      }
      var latencies: [Double] = []
      var checksum: UInt64 = 0
      var retained: ScreenSnapshot?
      let cpuStart = cpuSeconds()
      for frame in 0..<12 {
        let deadline = start + Double(frame) * 0.25
        if now() < deadline { try await Task.sleep(for: .seconds(deadline - now())) }
        let conversionStart = now()
        retained = try await converted(image, size: size)
        latencies.append((now() - conversionStart) * 1000)
        checksum += UInt64(retained!.pixels.bytes[frame * 4])
      }
      let delays = await heartbeat.value
      withExtendedLifetime(retained) {}
      results.append([
        "workload": "conversion-\(width)x\(height)", "frames": latencies.count,
        "cpu_ms": (cpuSeconds() - cpuStart) * 1000, "wall_ms": (now() - start) * 1000,
        "conversion_p50_ms": percentile(latencies, 0.5), "conversion_p95_ms": percentile(latencies, 0.95),
        "heartbeat_count": delays.count, "heartbeat_p95_ms": percentile(delays, 0.95),
        "heartbeat_p99_ms": percentile(delays, 0.99), "heartbeat_max_ms": delays.max()!,
        "heartbeat_over_8ms": delays.filter { $0 > 8.33 }.count,
        "heartbeat_over_16ms": delays.filter { $0 > 16.67 }.count, "checksum": checksum
      ])
    }
    let data = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
  }
}
