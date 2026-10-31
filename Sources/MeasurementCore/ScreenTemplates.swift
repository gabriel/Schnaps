import Foundation

public struct ScreenTemplate: Identifiable, Sendable {
  public let name: String
  public let width: Double, height: Double, top: Double, bottom: Double
  public var id: String { name }
  public init(
    _ name: String, _ width: Double, _ height: Double, top: Double = 0, bottom: Double = 0
  ) {
    self.name = name
    self.width = width
    self.height = height
    self.top = top
    self.bottom = bottom
  }
  /// Logical viewport sizes, rather than claims about a specific browser's variable chrome.
  public static let presets: [Self] = [
    .init("Phone · Compact", 320, 568, top: 20), .init("Phone · Small", 375, 667, top: 20),
    .init("Phone · Medium", 390, 844, top: 47, bottom: 34),
    .init("Phone · Standard", 393, 852, top: 59, bottom: 34),
    .init("Phone · Large", 430, 932, top: 59, bottom: 34),
    .init("Phone · Extra Large", 440, 956, top: 62, bottom: 34),
    .init("Android · Compact", 360, 640, top: 24, bottom: 24),
    .init("Android · Standard", 360, 800, top: 24, bottom: 24),
    .init("Android · Large", 412, 915, top: 24, bottom: 24),
    .init("Android · Wide", 480, 960, top: 24, bottom: 24),
    .init("Tablet · Mini", 744, 1133, top: 24, bottom: 20),
    .init("Tablet · Standard", 810, 1080, top: 24, bottom: 20),
    .init("Tablet · Air", 820, 1180, top: 24, bottom: 20),
    .init("Tablet · 11 inch", 834, 1194, top: 24, bottom: 20),
    .init("Tablet · 13 inch", 1024, 1366, top: 24, bottom: 20),
    .init("Android Tablet", 800, 1280, top: 24, bottom: 24),
    .init("Laptop · Compact", 1280, 800, top: 24), .init("Laptop · Standard", 1440, 900, top: 24),
    .init("Laptop · Large", 1512, 982, top: 38), .init("Laptop · Wide", 1728, 1117, top: 38),
    .init("Windows · Laptop", 1366, 768, bottom: 48),
    .init("Windows · Desktop", 1920, 1080, bottom: 48),
    .init("Desktop · HD", 1920, 1080), .init("Desktop · QHD", 2560, 1440),
    .init("Desktop · 4K", 3840, 2160),
    .init("Desktop · Ultrawide", 3440, 1440), .init("TV · 4:3", 1440, 1080),
    .init("TV · 720p", 1280, 720),
    .init("TV · 1080p", 1920, 1080), .init("TV · 4K", 3840, 2160),
    .init("Watch · Small", 162, 197), .init("Watch · Medium", 176, 215),
    .init("Watch · Large", 198, 242),
    .init("Social · Square", 1080, 1080), .init("Social · Portrait", 1080, 1350),
    .init("Social · Story", 1080, 1920),
  ]
}
