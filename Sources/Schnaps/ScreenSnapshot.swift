import AppKit
// Older macOS SDKs do not annotate ScreenCaptureKit's async results as Sendable.
// Capture objects are consumed only on the main actor after each await.
@preconcurrency import ScreenCaptureKit
import MeasurementCore

@MainActor
enum PreviewWindowRole {
    static let browser=NSUserInterfaceItemIdentifier("SchnapsBrowserPreview")
    static let image=NSUserInterfaceItemIdentifier("SchnapsImagePreview")
    static var capturableIDs:Set<CGWindowID> { Set(NSApp.windows.filter{$0.isVisible && ($0.identifier==browser || $0.identifier==image)}.map{CGWindowID($0.windowNumber)}) }
    static var sourceIDs:Set<CGWindowID> { Set(NSApp.windows.filter{$0.isVisible && $0.identifier==browser}.map{CGWindowID($0.windowNumber)}) }
}

// CGImage is immutable; its pixels and scale values can safely be read by workers.
struct ScreenSnapshot: @unchecked Sendable {
    static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("SchnapsSettings")

    let image: CGImage
    let pixels: PixelBuffer
    let scaleX: CGFloat
    let scaleY: CGFloat

    func dimensions(at point: CGPoint, tolerance: Int) -> Dimensions? {
        pixels.dimensions(at: CGPoint(x: point.x * scaleX, y: point.y * scaleY), tolerance: tolerance)?
            .scaled(x: 1 / scaleX, y: 1 / scaleY)
    }

    func objectBounds(in rect: CGRect, tolerance: Int, isCancelled: () -> Bool = { false }) -> CGRect? {
        let pixelsRect = CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY,
                                width: rect.width * scaleX, height: rect.height * scaleY)
        guard let result = pixels.objectBounds(in: pixelsRect, tolerance: tolerance, isCancelled: isCancelled) else { return nil }
        return CGRect(x: result.minX / scaleX, y: result.minY / scaleY,
                      width: result.width / scaleX, height: result.height / scaleY)
    }

    @MainActor
    static func capture() async throws -> [CGDirectDisplayID: ScreenSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Settings remains part of the frozen desktop, just like preview windows.
        let settingsIDs = NSApp.windows.filter {
            $0.isVisible && $0.identifier == settingsWindowIdentifier
        }.map { CGWindowID($0.windowNumber) }
        let capturableIDs = PreviewWindowRole.capturableIDs.union(settingsIDs)
        let ownWindows = content.windows.filter {
            $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
                && !capturableIDs.contains($0.windowID)
        }
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
            // Image decoding and allocation can stall input on Retina displays.
            let scaleX = CGFloat(image.width) / screen.frame.width
            let scaleY = CGFloat(image.height) / screen.frame.height
            let capturedImage = CapturedImage(image: image)
            if let snapshot = await Task.detached(priority: .userInitiated, operation: {
                guard let pixels = PixelBuffer(image: capturedImage.image) else { return nil as ScreenSnapshot? }
                return ScreenSnapshot(image: capturedImage.image, pixels: pixels, scaleX: scaleX, scaleY: scaleY)
            }).value {
                snapshots[id] = snapshot
            }
            try Task.checkCancellation()
        }
        return snapshots
    }
}

// Immutable Core Graphics images are safe to decode off the capture actor, including
// when building with SDKs that predate CGImage's Sendable annotation.
private struct CapturedImage: @unchecked Sendable {
    let image: CGImage
}
