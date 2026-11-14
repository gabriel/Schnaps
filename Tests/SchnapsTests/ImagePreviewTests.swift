import AppKit
import Testing
@testable import Schnaps

@MainActor
struct ImagePreviewTests {
  private enum CaptureError: Error { case failed }

  @Test(arguments: [false, true])
  func switchingToClipboardIgnoresOldWindowResult(fails: Bool) async throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let started = AsyncStream<Void>.makeStream()
    var starts = started.stream.makeAsyncIterator()
    var gate: CheckedContinuation<NSImage, any Error>?
    let model = ImagePreview(pasteboard: pasteboard, captureWindow: { _ in
      try await withCheckedThrowingContinuation { continuation in
        gate = continuation
        started.continuation.yield(())
      }
    })
    defer { model.setLive(false) }
    model.windowID = 1
    model.previewWindow()
    let request = Task { await model.readWindow() }
    await starts.next()
    model.paste()
    let clipboardImage = model.image
    let clipboardError = model.error
    if fails { gate?.resume(throwing: CaptureError.failed) }
    else { gate?.resume(returning: NSImage(size: CGSize(width: 20, height: 20))) }
    await request.value
    #expect(model.source == .clipboard)
    #expect(model.image === clipboardImage)
    #expect(model.error == clipboardError)
    #expect(model.live)
  }

  @Test(arguments: [false, true])
  func changingWindowIgnoresOldWindowResult(fails: Bool) async {
    let started = AsyncStream<Void>.makeStream()
    var starts = started.stream.makeAsyncIterator()
    var gate: CheckedContinuation<NSImage, any Error>?
    let currentImage = NSImage(size: CGSize(width: 40, height: 40))
    let model = ImagePreview(captureWindow: { id in
      if id == 2 { return currentImage }
      return try await withCheckedThrowingContinuation { continuation in
        gate = continuation
        started.continuation.yield(())
      }
    })
    defer { model.setLive(false) }
    model.windowID = 1
    model.previewWindow()
    let oldRequest = Task { await model.readWindow() }
    await starts.next()
    model.windowID = 2
    await model.readWindow()
    if fails { gate?.resume(throwing: CaptureError.failed) }
    else { gate?.resume(returning: NSImage(size: CGSize(width: 20, height: 20))) }
    await oldRequest.value
    #expect(model.image === currentImage)
    #expect(model.error == nil)
    #expect(model.live)
  }

  @Test(arguments: [false, true])
  func stoppingLiveIgnoresPendingResult(fails: Bool) async {
    let started = AsyncStream<Void>.makeStream()
    var starts = started.stream.makeAsyncIterator()
    var gate: CheckedContinuation<NSImage, any Error>?
    let model = ImagePreview(captureWindow: { _ in
      try await withCheckedThrowingContinuation { continuation in
        gate = continuation
        started.continuation.yield(())
      }
    })
    model.windowID = 1
    model.previewWindow()
    let request = Task { await model.readWindow() }
    await starts.next()
    model.setLive(false)
    if fails { gate?.resume(throwing: CaptureError.failed) }
    else { gate?.resume(returning: NSImage(size: CGSize(width: 20, height: 20))) }
    await request.value
    #expect(model.image == nil)
    #expect(model.error == nil)
    #expect(!model.live)
  }

  @Test func currentCaptureFailureStopsLivePreview() async {
    let model = ImagePreview(captureWindow: { _ in throw CaptureError.failed })
    model.windowID = 1
    model.previewWindow()
    await model.readWindow()
    #expect(model.error != nil)
    #expect(!model.live)
  }

  @Test func clipboardRefreshDecodesOnlyChangesAndClearsMissingImages() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let bitmap = try #require(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 8, bitsPerPixel: 32))
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    pasteboard.setData(data, forType: .png)
    let model = ImagePreview(pasteboard: pasteboard)
    model.paste()
    let first = try #require(model.image)
    model.refreshClipboard()
    #expect(model.image === first)
    #expect(model.error == nil)
    pasteboard.clearContents()
    pasteboard.setString("Text only", forType: .string)
    model.refreshClipboard()
    #expect(model.image == nil)
    #expect(model.error == "The clipboard does not contain an image.")
    pasteboard.clearContents()
    pasteboard.setData(data, forType: .png)
    model.refreshClipboard()
    #expect(model.image != nil)
    #expect(model.error == nil)
  }
}
