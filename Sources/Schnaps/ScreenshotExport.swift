import AppKit
import MeasurementCore
import UniformTypeIdentifiers

@MainActor
enum ScreenshotExport {
    enum ExportError: LocalizedError {
        case noCapture, emptySelection, encoding
        var errorDescription: String? {
            switch self {
            case .noCapture: L("Screen Recording is needed for screenshots.")
            case .emptySelection: L("Select an area or point between edges first.")
            case .encoding: L("The screenshot could not be encoded.")
            }
        }
    }
    static func image(
        snapshot: ScreenSnapshot, region: CGRect, togglePadding: Bool,
        padding: Int? = nil, scaleTo1x: Bool? = nil
    ) throws -> CGImage {
        let d = UserDefaults.standard
        let bounds = CGRect(
            x: 0, y: 0, width: CGFloat(snapshot.image.width) / snapshot.scaleX,
            height: CGFloat(snapshot.image.height) / snapshot.scaleY)
        let area = ScreenshotGeometry.region(
            region, in: bounds, padding: padding ?? d.integer(forKey: PreferenceKey.screenshotPadding),
            togglePadding: togglePadding)
        let pixelRect = ScreenshotGeometry.pixelRect(
            area, scaleX: snapshot.scaleX, scaleY: snapshot.scaleY,
            imageSize: CGSize(width: snapshot.image.width, height: snapshot.image.height))
        guard !pixelRect.isNull, pixelRect.width > 0, pixelRect.height > 0,
            let crop = snapshot.image.cropping(to: pixelRect)
        else { throw ExportError.emptySelection }
        guard scaleTo1x ?? d.bool(forKey: PreferenceKey.screenshotScale) else { return crop }
        let width = max(1, Int((CGFloat(crop.width) / snapshot.scaleX).rounded()))
        let height = max(1, Int((CGFloat(crop.height) / snapshot.scaleY).rounded()))
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ExportError.encoding }
        context.interpolationQuality = .high
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw ExportError.encoding }
        return image
    }
    static func encoded(_ image: CGImage, format: String) throws -> Data {
        let rep = NSBitmapImageRep(cgImage: image)
        guard
            let data = rep.representation(
                using: format == "jpg" ? .jpeg : .png,
                properties: format == "jpg" ? [.compressionFactor: 0.92] : [:])
        else { throw ExportError.encoding }
        return data
    }
    static func export(snapshot: ScreenSnapshot, region: CGRect, copy: Bool, togglePadding: Bool) throws -> URL? {
        let d = UserDefaults.standard
        let format = d.string(forKey: PreferenceKey.screenshotFormat) == "jpg" ? "jpg" : "png"
        let image = try image(snapshot: snapshot, region: region, togglePadding: togglePadding)
        let data = try encoded(image, format: format)
        if copy {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)])
            pasteboard.setData(
                data,
                forType: NSPasteboard.PasteboardType(format == "jpg" ? UTType.jpeg.identifier : UTType.png.identifier))
        }
        var url: URL?
        if !copy {
            let folder = URL(
                fileURLWithPath: d.string(forKey: PreferenceKey.screenshotFolder) ?? NSHomeDirectory() + "/Desktop",
                isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            let base = "Schnaps \(formatter.string(from:Date()))"
            var candidate = folder.appendingPathComponent(base + "." + format)
            var index = 2
            while FileManager.default.fileExists(atPath: candidate.path) {
                candidate = folder.appendingPathComponent("\(base) \(index).\(format)")
                index += 1
            }
            try data.write(to: candidate, options: .atomic)
            url = candidate
        }
        if d.bool(forKey: PreferenceKey.screenshotSound) { NSSound(named: "Tink")?.play() }
        return url
    }
}
