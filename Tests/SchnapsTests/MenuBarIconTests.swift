import AppKit
import Testing
@testable import Schnaps

@MainActor @Test func statusTracksVisibleToolsAndMeasurementPrioritySynchronously() throws {
    let suite = "Schnaps.Status.Tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let tools = DesignTools(defaults: defaults)
    let status = MenuBarStatus(designTools: tools)
    #expect(status.state == .idle)
    tools.markers = [DesignMarker(tool: .ruler, display: 0)]
    #expect(status.state == .idle) // A saved, hidden layout isn't active.
    tools.visible = true
    #expect(status.state == .marksVisible)
    status.measurementChanged(.findDimensions)
    #expect(status.state == .findDimensions)
    tools.hide()
    #expect(status.state == .findDimensions)
    status.measurementChanged(.area)
    #expect(status.state == .measureArea)
    tools.crosshair = true
    #expect(status.state == .measureArea)
    status.measurementChanged(nil)
    #expect(status.state == .marksVisible)
    tools.crosshair = false
    #expect(status.state == .idle)
    tools.loupe = true
    #expect(status.state == .marksVisible)
    tools.loupe = false
    tools.visible = true
    #expect(status.state == .marksVisible)
    _ = tools.dismissLastTool()
    #expect(status.state == .idle) // Last Escape updates immediately, despite willSet publishers.
    tools.editing = true
    #expect(status.state == .idle)
}

@MainActor @Test func splitCaliperHasFourDistinctTemplateMasksAtBothDisplayScales() throws {
    for scale in [1, 2] {
        let size = 22 * scale
        var masks = Set<Data>()
        for state in MenuBarIconState.allCases {
            let image = MenuBarIcon.image(for: state)
            #expect(image.isTemplate && image.size == NSSize(width: 22, height: 22))
            let context = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: NSRect(x: 0, y: 0, width: 22, height: 22))
            NSGraphicsContext.restoreGraphicsState()
            let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            let alpha = Data((0..<(size * size)).map { pixels[$0 * 4 + 3] })
            #expect(alpha.contains { $0 > 0 })
            #expect((0..<size).allSatisfy { alpha[$0] == 0 && alpha[(size - 1) * size + $0] == 0 })
            masks.insert(alpha)
        }
        #expect(masks.count == 4)
    }
}
