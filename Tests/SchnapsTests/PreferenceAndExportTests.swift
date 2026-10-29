import AppKit
import MeasurementCore
import Testing

@testable import Schnaps

@MainActor @Test func customToleranceSelectionKeepsPresetIdentity() {
    let name = "SchnapsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.register(defaults: MeasurementPreferences.defaults)
    #expect(MeasurementPreferences.selectedTolerance(in: defaults) == .medium)
    defaults.set(73, forKey: PreferenceKey.toleranceLow)
    MeasurementPreferences.selectTolerance(.low, in: defaults)
    #expect(MeasurementPreferences.selectedTolerance(in: defaults) == .low)
    #expect(defaults.integer(forKey: PreferenceKey.tolerance) == 73)
    defaults.set(-5, forKey: PreferenceKey.toleranceZero)
    defaults.set(500, forKey: PreferenceKey.toleranceHigh)
    #expect(MeasurementPreferences.threshold(.zero, in: defaults) == 0)
    #expect(MeasurementPreferences.threshold(.high, in: defaults) == 100)
}

@MainActor @Test func screenshotExportPreservesCropPixelsAndSupportsRetinaScaling() throws {
    let context = CGContext(
        data: nil, width: 400, height: 240, bitsPerComponent: 8, bytesPerRow: 1600,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor.red.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 240))
    let image = context.makeImage()!
    let snapshot = ScreenSnapshot(image: image, pixels: PixelBuffer(image: image)!, scaleX: 2, scaleY: 2)
    let rect = CGRect(x: 20, y: 10, width: 50, height: 30)
    let original = try ScreenshotExport.image(
        snapshot: snapshot, region: rect, togglePadding: false, padding: 0, scaleTo1x: false)
    #expect(original.width == 100)
    #expect(original.height == 60)
    let scaled = try ScreenshotExport.image(
        snapshot: snapshot, region: rect, togglePadding: false, padding: 10, scaleTo1x: true)
    #expect(scaled.width == 70)
    #expect(scaled.height == 50)
    let bytes = PixelBuffer(image: scaled)!.bytes
    #expect(bytes[0] == 255 && bytes[1] == 0 && bytes[2] == 0)
    for format in ["png", "jpg"] {
        let data = try ScreenshotExport.encoded(original, format: format)
        let decoded = try #require(NSBitmapImageRep(data: data))
        #expect(decoded.pixelsWide == 100 && decoded.pixelsHigh == 60)
        #expect(data.count > 0)
    }
    #expect(throws: ScreenshotExport.ExportError.self) {
        try ScreenshotExport.image(
            snapshot: snapshot, region: CGRect(x: 500, y: 500, width: 10, height: 10), togglePadding: false, padding: 0,
            scaleTo1x: false)
    }
}

@MainActor @Test func appearanceColorRoundTripsWithoutLosingChannels() {
    let color = NSColor(schnapsHex: "0A84FFFF")!
    #expect(color.schnapsHex == "0A84FFFF")
    #expect(NSColor(schnapsHex: "invalid") == nil)
    #expect(NSColor.white.relativeLuminance > NSColor.black.relativeLuminance)
}
