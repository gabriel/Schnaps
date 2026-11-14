import AppKit
import MeasurementCore
import Testing
@testable import Schnaps

private actor DetectionGate {
    private var pending: [Int: CheckedContinuation<CGRect?, Never>] = [:]
    private var nextID = 0
    let started: AsyncStream<Int>.Continuation

    init(started: AsyncStream<Int>.Continuation) { self.started = started }

    func scan() async -> CGRect? {
        let id = nextID
        nextID += 1
        return await withCheckedContinuation { continuation in
            pending[id] = continuation
            started.yield(id)
        }
    }

    func finish(_ id: Int, with result: CGRect) {
        pending.removeValue(forKey: id)?.resume(returning: result)
    }
}

@MainActor private func detectionSnapshot() throws -> ScreenSnapshot {
    let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                        bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try #require(context.makeImage())
    return ScreenSnapshot(image: image, pixels: try #require(PixelBuffer(image: image)), scaleX: 1, scaleY: 1)
}

// Share the serialized suite because AppKit window state is process-global.
extension OverlayStartupTests {
    @MainActor @Test func areaScanningKeepsUIAvailableAndDiscardsReplacedOrCancelledResults() async throws {
        let started = AsyncStream<Int>.makeStream()
        var starts = started.stream.makeAsyncIterator()
        let gate = DetectionGate(started: started.continuation)
        let detection = AreaDetection(detect: { _, _, _ in await gate.scan() })
        let snapshot = try detectionSnapshot()
        let old = CGRect(x: 10, y: 10, width: 20, height: 20)
        let latest = CGRect(x: 40, y: 40, width: 50, height: 50)
        var applied: [CGRect?] = []
        let first = detection.request(snapshot: snapshot, region: old, tolerance: 18) { applied.append($0) }
        #expect(detection.isPending)
        #expect(applied.isEmpty)
        #expect(await starts.next() == 0)
        // The main actor remains available while even an uncooperative scan is suspended.
        let second = detection.request(snapshot: snapshot, region: latest, tolerance: 18) { applied.append($0) }
        #expect(await starts.next() == 1)
        await gate.finish(0, with: old)
        await first.value
        #expect(applied.isEmpty)
        await gate.finish(1, with: latest)
        await second.value
        #expect(applied == [latest])
        #expect(!detection.isPending)
        let third = detection.request(snapshot: snapshot, region: old, tolerance: 18) { applied.append($0) }
        #expect(await starts.next() == 2)
        let waitingCommand = detection.completionForCurrent()
        detection.cancel()
        await gate.finish(2, with: old)
        await third.value
        #expect(await waitingCommand.value == false)
        #expect(applied == [latest])
        #expect(!detection.isPending)
    }

    @MainActor @Test func unrelatedPreferencesDoNotRestartAreaDetection() async throws {
        _ = NSApplication.shared
        let started = AsyncStream<Int>.makeStream()
        var starts = started.stream.makeAsyncIterator()
        let gate = DetectionGate(started: started.continuation)
        let detection = AreaDetection(detect: { _, _, _ in await gate.scan() })
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = MeasurementView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), scale: 1,
                                   snapshot: try detectionSnapshot(), mode: .findDimensions, areaDetection: detection)
        window.contentView = view
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                           clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 20, y: 180)))
        view.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: 180, y: 20)))
        view.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 180, y: 20)))
        #expect(await starts.next() == 0)
        view.synchronizePreferences()
        await gate.finish(0, with: CGRect(x: 50, y: 50, width: 100, height: 100))
        #expect(await detection.completionForCurrent().value)
        #expect(!detection.isPending)
    }
}
