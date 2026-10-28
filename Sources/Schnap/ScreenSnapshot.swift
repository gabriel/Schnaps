import AppKit
// Older macOS SDKs do not annotate ScreenCaptureKit's async results as Sendable.
// Capture objects are consumed only on the main actor after each await.
@preconcurrency import ScreenCaptureKit
import MeasurementCore

struct ScreenSnapshot {
    let image: CGImage
    let pixels: PixelBuffer
    let scaleX: CGFloat
    let scaleY: CGFloat

    func edges(at point: CGPoint, tolerance: Int, bounds: CGRect) -> CGRect? {
        guard let rect = pixels.edges(at: CGPoint(x: point.x * scaleX, y: point.y * scaleY),
                                      tolerance: tolerance) else { return nil }
        return CGRect(x: rect.minX / scaleX, y: rect.minY / scaleY,
                      width: rect.width / scaleX, height: rect.height / scaleY).intersection(bounds)
    }

    @MainActor
    static func capture() async throws -> [CGDirectDisplayID: ScreenSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
        var snapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  let display = content.displays.first(where: { $0.displayID == id }) else { continue }
            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * screen.backingScaleFactor)
            config.height = Int(screen.frame.height * screen.backingScaleFactor)
            config.showsCursor = false
            config.captureResolution = .best
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            if let pixels = PixelBuffer(image: image) {
                snapshots[id] = ScreenSnapshot(image: image, pixels: pixels,
                                               scaleX: CGFloat(image.width) / screen.frame.width,
                                               scaleY: CGFloat(image.height) / screen.frame.height)
            }
        }
        return snapshots
    }
}
