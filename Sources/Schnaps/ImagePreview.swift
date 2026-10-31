import AppKit
@preconcurrency import ScreenCaptureKit
import SwiftUI

@MainActor
final class ImagePreview: NSObject, ObservableObject, NSWindowDelegate {
  static let shared = ImagePreview()
  @Published var image: NSImage?
  @Published var error: String?
  @Published var source = "Clipboard"
  @Published var windowID: UInt32?
  @Published var displayID: UInt32 = 0
  @Published var live = false
  private var file: URL?
  private var window: NSWindow?
  private var task: Task<Void, Never>?
  private var fileDate: Date?
  func show() {
    // Keep the marks, but let clicks and keyboard focus reach this native window.
    DesignTools.shared.editing = false
    if !NSScreen.screens.contains(where: { DesignTools.displayID($0) == displayID }),
      let main = NSScreen.main
    {
      displayID = DesignTools.displayID(main)
    }
    if window == nil {
      let window = NSWindow(
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
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
  func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image, .pdf]
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      file = url
      fileDate = nil
      source = "File"
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
    source = "Clipboard"
    image = NSImage(pasteboard: .general)
    if image == nil { error = "The clipboard does not contain an image." } else { error = nil }
  }
  func setLive(_ enabled: Bool) {
    live = enabled
    task?.cancel()
    task = nil
    guard enabled else { return }
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        // Hidden preview windows must not keep recording the screen.
        if self.window?.isVisible == true {
          if self.source == "Window" {
            await self.readWindow()
          } else if self.source == "File" {
            self.readFile()
          } else if self.source == "Clipboard",
            NSPasteboard.general.canReadObject(forClasses: [NSImage.self])
          {
            self.image = NSImage(pasteboard: .general)
          }
        }
        do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
      }
    }
  }
  private func readWindow() async {
    ScreenRecordingPermission.shared.refresh()
    guard ScreenRecordingPermission.shared.granted else {
      error = "Allow Screen Recording in Settings → Permissions to preview a window."
      setLive(false)
      return
    }
    guard let windowID else { return }
    do {
      let content = try await SCShareableContent.excludingDesktopWindows(
        true, onScreenWindowsOnly: false)
      guard let source = content.windows.first(where: { $0.windowID == windowID }) else {
        error = "The selected window has closed."
        setLive(false)
        return
      }
      let config = SCStreamConfiguration()
      let scale = min(2, sqrt(16_000_000 / max(1, source.frame.width * source.frame.height)))
      config.width = max(1, Int(source.frame.width * scale))
      config.height = max(1, Int(source.frame.height * scale))
      config.showsCursor = false
      let captured = try await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(desktopIndependentWindow: source), configuration: config)
      guard !Task.isCancelled else { return }
      image = NSImage(cgImage: captured, size: source.frame.size)
      error = nil
    } catch {
      self.error = error.localizedDescription
      setLive(false)
    }
  }
  func windowWillClose(_ notification: Notification) {
    setLive(false)
    if source == "Window" { image = nil }
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
          model.source = "Window"
          model.setLive(true)
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
