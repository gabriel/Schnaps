import AppKit
@preconcurrency import ScreenCaptureKit
import SwiftUI

@MainActor
final class ImagePreview: NSObject, ObservableObject, NSWindowDelegate {
  static let shared = ImagePreview()
  @Published var image: NSImage?
  @Published var error: String?
  enum Source { case clipboard, file, window }
  @Published private(set) var source = Source.clipboard {
    didSet { if source != oldValue { setLive(live) } }
  }
  @Published var windowID: UInt32? {
    didSet { if windowID != oldValue, source == .window { setLive(live) } }
  }
  @Published var displayID: UInt32 = 0
  @Published private(set) var live = false
  private var file: URL?
  private var window: NSWindow?
  private var task: Task<Void, Never>?
  private var fileDate: Date?
  private var generation = UUID()
  private var clipboardChangeCount: Int?
  private let pasteboard: NSPasteboard
  private let captureWindow: @MainActor (UInt32) async throws -> NSImage

  init(pasteboard: NSPasteboard = .general,
       captureWindow: @escaping @MainActor (UInt32) async throws -> NSImage = ImagePreview.captureWindow) {
    self.pasteboard = pasteboard
    self.captureWindow = captureWindow
    super.init()
  }
  func show() {
    // Keep the marks, but let clicks and keyboard focus reach this native window.
    DesignTools.shared.editing = false
    if !NSScreen.screens.contains(where: { DesignTools.displayID($0) == displayID }),
      let main = NSScreen.main
    {
      displayID = DesignTools.displayID(main)
    }
    if window == nil {
      let window = AppWindow(
        contentRect: CGRect(x: 0, y: 0, width: 800, height: 700),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.identifier = PreviewWindowRole.image
      window.title = "Image & Window Preview"
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.contentView = NSHostingView(rootView: ImagePreviewView(model: self))
      window.center()
      self.window = window
    }
    window?.makeKeyAndOrderFront(nil)
  }
  func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image, .pdf]
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      file = url
      fileDate = nil
      source = .file
      readFile()
      setLive(true)
    }
  }
  private func readFile() {
    guard let file else { return }
    guard
      let properties = try? file.resourceValues(forKeys: [
        .fileSizeKey, .contentModificationDateKey,
      ]), (properties.fileSize ?? 0) <= 64_000_000
    else {
      error = "Choose an image or PDF up to 64 MB."
      return
    }
    if fileDate != properties.contentModificationDate || image == nil {
      image = NSImage(contentsOf: file)
      fileDate = properties.contentModificationDate
    }
    if image == nil { error = "The image could not be opened." } else { error = nil }
  }
  func paste() {
    source = .clipboard
    refreshClipboard(force: true)
  }
  func refreshClipboard(force: Bool = false) {
    guard force || clipboardChangeCount != pasteboard.changeCount else { return }
    clipboardChangeCount = pasteboard.changeCount
    image = NSImage(pasteboard: pasteboard)
    if image == nil { error = "The clipboard does not contain an image." } else { error = nil }
  }
  func previewWindow() {
    source = .window
    setLive(true)
  }
  func setLive(_ enabled: Bool) {
    generation = UUID()
    live = enabled
    task?.cancel()
    task = nil
    guard enabled else { return }
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        // Hidden preview windows must not keep recording the screen.
        if self.window?.isVisible == true {
          switch self.source {
          case .window: await self.readWindow()
          case .file: self.readFile()
          case .clipboard: self.refreshClipboard()
          }
        }
        do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
      }
    }
  }
  func readWindow() async {
    guard let windowID, source == .window else { return }
    let token = generation
    do {
      let captured = try await captureWindow(windowID)
      guard !Task.isCancelled, generation == token else { return }
      image = captured
      error = nil
    } catch {
      guard !Task.isCancelled, generation == token else { return }
      self.error = error.localizedDescription
      setLive(false)
    }
  }
  private static func captureWindow(_ windowID: UInt32) async throws -> NSImage {
    ScreenRecordingPermission.shared.refresh()
    guard ScreenRecordingPermission.shared.granted else {
      throw PreviewError.permissionDenied
    }
    let content = try await SCShareableContent.excludingDesktopWindows(
      true, onScreenWindowsOnly: false)
    try Task.checkCancellation()
    guard let source = content.windows.first(where: { $0.windowID == windowID }) else {
      throw PreviewError.windowClosed
    }
    let config = SCStreamConfiguration()
    let scale = min(2, sqrt(16_000_000 / max(1, source.frame.width * source.frame.height)))
    config.width = max(1, Int(source.frame.width * scale))
    config.height = max(1, Int(source.frame.height * scale))
    config.showsCursor = false
    let captured = try await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(desktopIndependentWindow: source), configuration: config)
    return NSImage(cgImage: captured, size: source.frame.size)
  }
  private enum PreviewError: LocalizedError {
    case permissionDenied, windowClosed
    var errorDescription: String? {
      switch self {
      case .permissionDenied:
        "Allow Screen Recording in Settings → Permissions to preview a window."
      case .windowClosed:
        "The selected window has closed."
      }
    }
  }
  func windowWillClose(_ notification: Notification) {
    setLive(false)
    if source == .window { image = nil }
  }
  func moveToDisplay() {
    guard let screen = NSScreen.screens.first(where: { DesignTools.displayID($0) == displayID })
    else { return }
    window?.setFrame(screen.visibleFrame.insetBy(dx: 40, dy: 40), display: true)
  }
}
private struct ImagePreviewView: View {
  @ObservedObject var model: ImagePreview
  @ObservedObject var tools = DesignTools.shared
  var body: some View {
    VStack {
      HStack {
        Button("Open File…", action: model.chooseFile)
        Button("Paste Image", action: model.paste)
        Toggle("Live", isOn: Binding(get: { model.live }, set: { model.setLive($0) }))
        Spacer()
        Picker("Display", selection: $model.displayID) {
          ForEach(NSScreen.screens, id: \.self) {
            Text($0.localizedName).tag(DesignTools.displayID($0))
          }
        }.frame(maxWidth: 260)
        Button("Move", action: model.moveToDisplay)
      }
      HStack {
        Button("Refresh Windows", action: tools.refreshWindows)
        Picker("Window", selection: $model.windowID) {
          Text("Choose Window").tag(UInt32?.none)
          ForEach(tools.availableWindows) { Text($0.title).tag(Optional($0.id)) }
        }
        Button("Preview Window") {
          model.previewWindow()
        }.disabled(model.windowID == nil)
      }
      Divider()
      if let image = model.image {
        Image(nsImage: image).resizable().scaledToFit().frame(
          maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView("Choose an image or window", systemImage: "photo.on.rectangle")
      }
      if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red) }
    }.padding(12).onDisappear { model.setLive(false) }
  }
}
