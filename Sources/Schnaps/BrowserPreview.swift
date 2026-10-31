import AppKit
import MeasurementCore
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
final class BrowserPreview: NSObject, ObservableObject, WKNavigationDelegate {
  static let shared = BrowserPreview()
  let webView: WKWebView
  @Published var address = ""
  @Published var width = 960.0
  @Published var grid = false
  @Published var columns = 12
  @Published var busy = false
  @Published var error: String?
  private var window: NSWindow?
  override init() {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    webView = WKWebView(frame: .zero, configuration: config)
    super.init()
    webView.navigationDelegate = self
  }
  func show() {
    if window == nil {
      let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 1060, height: 760),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.identifier = PreviewWindowRole.browser
      window.title = "Responsive Preview"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: BrowserPreviewView(model: self))
      window.center()
      self.window = window
    }
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
  func load() {
    let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: text.contains("://") ? text : "https://" + text),
      ["https", "http"].contains(url.scheme), url.host != nil, url.user == nil, url.password == nil
    else {
      error = "Enter an http or https website address."
      return
    }
    address = url.absoluteString
    busy = true
    webView.load(URLRequest(url: url))
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    busy = false
    address = webView.url?.absoluteString ?? address
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    busy = false
    self.error = error.localizedDescription
  }
  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    busy = false
    self.error = error.localizedDescription
  }
  func export(png: Bool) {
    guard webView.url != nil, !busy else { return }
    busy = true
    Task {
      defer { busy = false }
      do {
        let data: Data
        if png {
          data = try await capturePNG()
        } else {
          data = try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: WKPDFConfiguration()) { continuation.resume(with: $0) }
          }
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = png ? [.png] : [.pdf]
        panel.nameFieldStringValue = "Schnaps Page." + (png ? "png" : "pdf")
        if panel.runModal() == .OK, let url = panel.url {
          try data.write(to: url, options: .atomic)
        }
      } catch { self.error = error.localizedDescription }
    }
  }
  static func rasterSize(width: Double, height: Double) throws -> (Int, Int) {
    guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 16000, height <= 32000,
      ceil(width) * ceil(height) <= 32_000_000
    else {
      throw TextCodecError.invalid(
        "This page is too large for PNG. Save it as a PDF instead (PNG limit: 32 megapixels).")
    }
    return (Int(ceil(width)), Int(ceil(height)))
  }
  private func captureScript(_ body: String, arguments: [String: Any] = [:]) async throws
    -> [String: Double]
  {
    try await withCheckedThrowingContinuation { continuation in
      webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .defaultClient) {
        result in
        switch result {
        case .success(let value):
          continuation.resume(
            returning: (value as? [String: NSNumber])?.mapValues(\.doubleValue) ?? [:])
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }
  private func capturePNG() async throws -> Data {
    let originalURL = webView.url
    let setup = #"""
      const changes=[];
      for (const element of document.querySelectorAll('*')) {
        const position=getComputedStyle(element).position;
        if (position==='fixed'||position==='sticky') {
          changes.push([element,element.getAttribute('style')]);
          element.style.setProperty('position',position==='fixed'?'absolute':'relative','important');
        }
      }
      globalThis.schnapsCapture={x:scrollX,y:scrollY,changes};
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
      return {width:document.documentElement.clientWidth,height:Math.max(document.documentElement.scrollHeight,document.body?.scrollHeight||0),viewport:innerHeight};
      """#
    let restore = #"""
      const saved=globalThis.schnapsCapture;
      if(saved) {
        for(const [element,style] of saved.changes) { if(style===null)element.removeAttribute('style');else element.setAttribute('style',style); }
        scrollTo(saved.x,saved.y);delete globalThis.schnapsCapture;
      }
      return {};
      """#
    do {
      let geometry = try await captureScript(setup)
      let (width, height) = try Self.rasterSize(
        width: geometry["width"] ?? 0, height: geometry["height"] ?? 0)
      guard let viewport = geometry["viewport"], viewport.isFinite, viewport > 0,
        let context = CGContext(
          data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { throw ScreenshotExport.ExportError.encoding }
      context.setFillColor(NSColor.white.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      var y = 0.0
      while y < Double(height) {
        guard webView.url == originalURL else {
          throw TextCodecError.invalid(
            "The page changed during capture. Try again after it finishes loading.")
        }
        let position = try await captureScript(
          "scrollTo(0,y);await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));return {y:scrollY};",
          arguments: ["y": y])
        let offset = max(0, y - (position["y"] ?? y))
        let part = min(viewport - offset, Double(height) - y)
        guard part >= 1 else { throw ScreenshotExport.ExportError.encoding }
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: offset, width: Double(width), height: part)
        config.snapshotWidth = NSNumber(value: width)
        config.afterScreenUpdates = true
        let image = try await webView.takeSnapshot(configuration: config)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
          throw ScreenshotExport.ExportError.encoding
        }
        context.draw(
          cg, in: CGRect(x: 0, y: Double(height) - y - part, width: Double(width), height: part))
        y += part
      }
      guard let image = context.makeImage(),
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
      else { throw ScreenshotExport.ExportError.encoding }
      _ = try? await captureScript(restore)
      return data
    } catch {
      _ = try? await captureScript(restore)
      throw error
    }
  }

}

private struct BrowserContent: NSViewRepresentable {
  let webView: WKWebView
  func makeNSView(context: Context) -> WKWebView { webView }
  func updateNSView(_ nsView: WKWebView, context: Context) {}
}
private struct BrowserPreviewView: View {
  @ObservedObject var model: BrowserPreview
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        TextField("Website address", text: $model.address).onSubmit(model.load)
        Button("Open", action: model.load).disabled(model.busy)
        if model.busy { ProgressView().controlSize(.small) }
      }.padding(10)
      HStack {
        TextField("Viewport width", value: $model.width, format: .number).frame(width: 150)
        Picker("Breakpoint", selection: $model.width) {
          ForEach([320.0, 375, 393, 768, 960, 1024, 1280, 1440], id: \.self) {
            Text("\(Int($0)) pt").tag($0)
          }
        }.frame(width: 180)
        Toggle("Grid", isOn: $model.grid)
        Spacer()
        Button("Full-page PNG") { model.export(png: true) }.disabled(model.busy)
        Button("Full-page PDF") { model.export(png: false) }.disabled(model.busy)
      }.padding([.horizontal, .bottom], 10)
      Divider()
      GeometryReader { geometry in
        ScrollView(.horizontal) {
          BrowserContent(webView: model.webView).frame(
            width: max(240, min(3840, model.width.isFinite ? model.width : 960)),
            height: geometry.size.height
          )
          .overlay {
            if model.grid {
              Canvas { context, size in
                let width = size.width / 12
                for index in 0..<12 {
                  let rect = CGRect(
                    x: Double(index) * width + 4, y: 0, width: width - 8, height: size.height)
                  context.fill(Path(rect), with: .color(.blue.opacity(0.10)))
                }
              }.allowsHitTesting(false)
            }
          }
        }
      }
    }
    .alert(
      "Responsive Preview",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
  }
}
