import AppKit
import MeasurementCore
import Testing
@testable import Schnaps

@MainActor
private func testSnapshot() throws -> ScreenSnapshot {
    let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                        bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
    let image = try #require(context.makeImage())
    return ScreenSnapshot(image: image, pixels: try #require(PixelBuffer(image: image)), scaleX: 1, scaleY: 1)
}

@MainActor @Suite(.serialized)
struct OverlayStartupTests {
    @Test func overlayAppearsBeforeCaptureAndIgnoresCancelledCapture() async throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.screens.first)
        let id = try #require(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).uint32Value
        let snapshot = try testSnapshot()
        let started = AsyncStream<Int>.makeStream()
        let finished = AsyncStream<Int>.makeStream()
        var starts = started.stream.makeAsyncIterator()
        var finishes = finished.stream.makeAsyncIterator()
        var gates: [CheckedContinuation<Void, Never>] = []
        let controller = OverlayController(captureScreens: {
            let index = gates.count
            await withCheckedContinuation { continuation in
                gates.append(continuation)
                started.continuation.yield(index)
            }
            finished.continuation.yield(index)
            return [id: snapshot]
        }, canCapture: { true })
        defer { controller.stop() }
        controller.toggle(mode: .findDimensions)
        #expect(controller.isActive)
        #expect(controller.windows.count == NSScreen.screens.count)
        #expect(controller.windows.allSatisfy { $0.isVisible })
        #expect(gates.isEmpty) // Presentation is synchronous; capture has not even started.
        #expect(await starts.next() == 0)
        controller.stop()
        controller.toggle(mode: .findDimensions)
        #expect(await starts.next() == 1)
        gates[0].resume()
        #expect(await finishes.next() == 0)
        #expect(controller.windows.allSatisfy { ($0.contentView as? MeasurementView)?.captureSnapshot == nil })
        gates[1].resume()
        #expect(await finishes.next() == 1)
        let view = try #require(controller.windows.first { $0.screen == screen }?.contentView as? MeasurementView)
        #expect(view.captureSnapshot != nil)
    }

    @Test func areaBorderKeepsOverlayColorAcrossBackgroundsAndHonorsExplicitColorSwitch() throws {
        let defaults = UserDefaults.standard
        let previousContrast = defaults.object(forKey: PreferenceKey.autoContrast)
        defaults.set(true, forKey: PreferenceKey.autoContrast)
        defer {
            if let previousContrast { defaults.set(previousContrast, forKey: PreferenceKey.autoContrast) }
            else { defaults.removeObject(forKey: PreferenceKey.autoContrast) }
        }
        let primary = MeasurementPreferences.color(PreferenceKey.overlayColor)
        let alternative = MeasurementPreferences.color(PreferenceKey.alternativeColor)
        for mode in [MeasurementMode.findDimensions, .area] {
            for background in [primary, NSColor.white, NSColor.black] {
                let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                                    bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
                                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(background.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
                let image = try #require(context.makeImage())
                let snapshot = ScreenSnapshot(image: image, pixels: try #require(PixelBuffer(image: image)), scaleX: 1, scaleY: 1)
                let view = MeasurementView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), scale: 1,
                                           snapshot: snapshot, mode: mode)
                #expect(view.areaMeasurementColor.schnapsHex == primary.schnapsHex)
                let toggle = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                          timestamp: 0, windowNumber: 0, context: nil,
                                                          characters: "x", charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 7))
                view.keyDown(with: toggle)
                #expect(view.areaMeasurementColor.schnapsHex == alternative.schnapsHex)
                view.keyDown(with: toggle)
                #expect(view.areaMeasurementColor.schnapsHex == primary.schnapsHex)
            }
        }
    }

    @Test func automaticAreaSnapTracksModifiersAndAcceptsFirstFrameDuringDrag() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = MeasurementView(frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                   scale: 1, snapshot: nil, mode: .findDimensions)
        window.contentView = view
        func event(_ type: NSEvent.EventType, _ point: CGPoint, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: CGPoint(x: point.x, y: 200 - point.y),
                                           modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        let start = CGPoint(x: 20, y: 20), end = CGPoint(x: 180, y: 180)
        view.mouseDown(with: try event(.leftMouseDown, start))
        view.mouseDragged(with: try event(.leftMouseDragged, end))
        #expect(view.showsSnapIndicator)
        view.mouseDragged(with: try event(.leftMouseDragged, end, flags: .option))
        #expect(!view.showsSnapIndicator)
        view.mouseDragged(with: try event(.leftMouseDragged, end, flags: .shift))
        #expect(!view.showsSnapIndicator)
        view.mouseDragged(with: try event(.leftMouseDragged, end))
        #expect(view.showsSnapIndicator)
        view.updateSnapshot(try testSnapshot())
        #expect(view.captureSnapshot != nil)
        view.mouseUp(with: try event(.leftMouseUp, end))
        #expect(view.showsSnapIndicator)
        view.rightMouseDown(with: try event(.rightMouseDown, start))
        view.rightMouseDragged(with: try event(.rightMouseDragged, end))
        #expect(!view.showsSnapIndicator)
        view.rightMouseUp(with: try event(.rightMouseUp, end))
        #expect(!view.showsSnapIndicator)

        // Completing an area before the first capture must still snap once it arrives.
        let pending = MeasurementView(frame: view.frame, scale: 1, snapshot: nil, mode: .findDimensions)
        window.contentView = pending
        pending.mouseDown(with: try event(.leftMouseDown, start))
        pending.mouseDragged(with: try event(.leftMouseDragged, end))
        pending.mouseUp(with: try event(.leftMouseUp, end))
        #expect(pending.showsSnapIndicator)
        pending.updateSnapshot(try testSnapshot())
        var capturedRegion: CGRect?
        pending.onCapture = { region, _, _ in capturedRegion = region }
        let capture = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                   timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                   characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8))
        pending.keyDown(with: capture)
        #expect(capturedRegion == CGRect(x: 50, y: 50, width: 100, height: 100))

        let area = MeasurementView(frame: view.frame, scale: 1, snapshot: try testSnapshot(), mode: .area)
        window.contentView = area
        area.mouseDown(with: try event(.leftMouseDown, start))
        area.mouseDragged(with: try event(.leftMouseDragged, end))
        #expect(!area.showsSnapIndicator)
    }
}
