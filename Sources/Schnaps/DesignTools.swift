import AppKit
import Combine
import MeasurementCore
import SwiftUI

enum DesignTool: String, CaseIterable, Identifiable, Codable {
  case ruler = "Rulers"
  case guides = "Guides"
  case frames = "Frames"
  case overlay = "Design Overlay"
  case screens = "Screens"
  case loupe = "Loupe"
  case crosshair = "Crosshair"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .ruler: "ruler"
    case .guides: "line.3.horizontal"
    case .frames: "rectangle.dashed"
    case .overlay: "square.3.layers.3d"
    case .screens: "display"
    case .loupe: "plus.magnifyingglass"
    case .crosshair: "scope"
    }
  }
}

struct DesignMarker: Identifiable, Codable, Equatable {
  var id = UUID()
  var tool: DesignTool
  var display: UInt32
  var x = 100.0, y = 100.0, width = 320.0, height = 240.0
  var angle = 0.0, scale = 1.0
  var vertical = false, locked = false
  var isVisible = true
  var columns = 1, rows = 1
  var spacing = 0.0, margin = 16.0, gutter = 16.0
  var opacity = 0.6, imageName: String?
  var marks = true, calipers = false, square = false, safeAreas = false
  var color = "0A84FFFF"
  var attachedWindow: UInt32?
  var topInset = 0.0, bottomInset = 0.0, leftInset = 0.0, rightInset = 0.0, keyboardHeight = 0.0
  var aspectRatio = 0.0
  var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
  var end: CGPoint {
    DesignGeometry.endpoint(origin: CGPoint(x: x, y: y), length: width, degrees: angle)
  }
  mutating func validate() {
    x = x.isFinite ? min(100000, max(-100000, x)) : 100
    y = y.isFinite ? min(100000, max(-100000, y)) : 100
    width = width.isFinite ? min(16000, max(1, width)) : 320
    height = height.isFinite ? min(16000, max(1, height)) : 240
    angle = angle.isFinite ? angle.truncatingRemainder(dividingBy: 360) : 0
    scale = scale.isFinite ? min(1000, max(0.01, scale)) : 1
    spacing = spacing.isFinite ? min(1000, max(0, spacing)) : 0
    margin = margin.isFinite ? min(1000, max(0, margin)) : 0
    gutter = gutter.isFinite ? min(1000, max(0, gutter)) : 0
    opacity = opacity.isFinite ? min(1, max(0, opacity)) : 0.6
    columns = min(64, max(1, columns))
    rows = min(64, max(1, rows))
    for key in [
      \Self.topInset, \Self.bottomInset, \Self.leftInset, \Self.rightInset, \Self.keyboardHeight,
    ] {
      self[keyPath: key] = self[keyPath: key].isFinite ? min(16000, max(0, self[keyPath: key])) : 0
    }
    aspectRatio = aspectRatio.isFinite ? min(100, max(0, aspectRatio)) : 0
  }
}

enum VisionSimulation: String, CaseIterable, Identifiable {
  case normal = "Normal"
  case protanopia = "Protanopia"
  case deuteranopia = "Deuteranopia"
  case tritanopia = "Tritanopia"
  case grayscale = "Grayscale"
  case blur = "Blurred vision"
  var id: Self { self }
}

@MainActor
final class DesignTools: ObservableObject {
  static let shared = DesignTools()
  @Published var markers: [DesignMarker] = [] {
    didSet {
      presentationOrder.removeAll { entry in
        if case .marker(let id) = entry { return !markers.contains { $0.id == id } }
        return false
      }
      for marker in markers where marker.isVisible {
        if !oldValue.contains(where: { $0.id == marker.id && $0.isVisible }) {
          recordPresentation(.marker(marker.id))
        }
      }
      persist()
      redraw?()
    }
  }
  @Published var selectedID: UUID?
  @Published var tool: DesignTool = .ruler
  @Published var visible = false {
    didSet {
      if visible && !oldValue {
        for marker in markers where marker.isVisible { recordPresentation(.marker(marker.id)) }
      }
      redraw?()
    }
  }
  @Published var editing = false { didSet { redraw?() } }
  @Published var linked = false
  @Published var synchronizeLength = false
  @Published var synchronizeAngle = false
  @Published var crosshair = false {
    didSet { if crosshair && !oldValue { recordPresentation(.crosshair) }; redraw?() }
  }
  @Published var relativeOrigin: CGPoint? { didSet { redraw?() } }
  @Published var lineWidth = 1.0 { didSet { redraw?() } }
  @Published var loupe = false {
    didSet { if loupe && !oldValue { recordPresentation(.loupe) }; redraw?() }
  }
  @Published var zoom = 8.0 { didSet { redraw?() } }
  @Published var pixelGrid = true
  @Published var colorFormat = "Hex"
  @Published var colorValue = "—"
  @Published var referenceColor = "—"
  @Published var referenceFormat = "RGB"
  @Published var frozenLoupe: CGPoint?
  @Published var contrast = "—"
  @Published var vision: VisionSimulation = .normal { didSet { redraw?() } }
  @Published var retinaPreview = false
  @Published var swatches: [String] = [] {
    didSet { defaults.set(swatches, forKey: "designSwatches") }
  }
  @Published var error: String?
  @Published var availableWindows: [DesignWindow] = []
  var hasVisibleMarkers: Bool { visible && markers.contains(where: \.isVisible) }
  var isActive: Bool { hasVisibleMarkers || loupe || crosshair }
  private enum Presentation: Equatable { case marker(UUID), loupe, crosshair }
  private var presentationOrder: [Presentation] = []
  private func recordPresentation(_ entry: Presentation) {
    presentationOrder.removeAll { $0 == entry }
    presentationOrder.append(entry)
  }
  /// Dismiss appearances, not saved geometry or arbitrary edits. Restoring a marker
  /// from the inspector makes it the newest appearance again.
  @discardableResult func dismissLastTool() -> Bool {
    let last = presentationOrder.last { entry in
      switch entry {
      case .marker(let id): visible && markers.contains { $0.id == id && $0.isVisible }
      case .loupe: loupe
      case .crosshair: crosshair
      }
    }
    guard let last else { return false }
    presentationOrder.removeAll { $0 == last }
    switch last {
    case .marker(let id):
      if let index = markers.firstIndex(where: { $0.id == id }) { markers[index].isVisible = false }
      if selectedID == id { selectedID = markers.last(where: \.isVisible)?.id }
      if !markers.contains(where: \.isVisible) { visible = false }
    case .loupe: loupe = false
    case .crosshair: crosshair = false
    }
    if !isActive { editing = false }
    return true
  }
  var redraw: (() -> Void)?
  var show: ((DesignTool) -> Void)?
  var dismiss: (() -> Void)?
  var capture: ((Bool) -> Void)?
  var colorSample: InspectorColor?
  var contrastSample: InspectorColor?
  private let key = "designMarkers.v1"
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let items = try? JSONDecoder().decode([DesignMarker].self, from: data)
    {
      markers = Array(items.prefix(100)).map {
        var m = $0
        m.validate()
        m.attachedWindow = nil
        return m
      }
    }
    swatches = Array((defaults.stringArray(forKey: "designSwatches") ?? []).prefix(128))
    rehomeMissingDisplays()
  }
  func rehomeMissingDisplays() {
    guard let main = NSScreen.main else { return }
    let ids = Set(NSScreen.screens.map { Self.displayID($0) })
    let result = markers.map { marker in
      guard !ids.contains(marker.display) else { return marker }
      var marker = marker
      marker.display = Self.displayID(main)
      marker.x = min(max(0, marker.x), max(0, main.frame.width - min(40, marker.width)))
      marker.y = min(max(0, marker.y), max(0, main.frame.height - min(40, marker.height)))
      return marker
    }
    if result != markers { markers = result }
  }
  var selected: DesignMarker? { markers.first { $0.id == selectedID } }
  func update(_ change: (inout DesignMarker) -> Void) {
    guard let index = markers.firstIndex(where: { $0.id == selectedID }) else { return }
    let old = markers[index]
    var marker = old
    change(&marker)
    marker.validate()
    if marker.aspectRatio > 0 {
      if marker.width != old.width {
        marker.height = marker.width / marker.aspectRatio
      } else if marker.height != old.height {
        marker.width = marker.height * marker.aspectRatio
      }
      marker.validate()
    }
    var result = markers
    result[index] = marker
    if linked {
      for i in result.indices
      where result[i].id != marker.id && result[i].tool == marker.tool
        && result[i].display == marker.display && !result[i].locked
      {
        result[i].x += marker.x - old.x
        result[i].y += marker.y - old.y
        result[i].validate()
      }
    }
    if marker.tool == .ruler {
      for i in result.indices where result[i].id != marker.id && result[i].tool == .ruler {
        if synchronizeLength { result[i].width = marker.width }
        if synchronizeAngle { result[i].angle = marker.angle }
      }
    }
    markers = result
  }
  func add(_ kind: DesignTool, screen: NSScreen? = nil) {
    let screen =
      screen ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
      ?? NSScreen.main
    guard let screen else { return }
    let display = Self.displayID(screen)
    if kind == .ruler && markers.filter({ $0.tool == .ruler }).count >= 2 {
      selectedID = markers.first(where: { $0.tool == .ruler && !$0.isVisible })?.id
        ?? markers.first(where: { $0.tool == .ruler })?.id
      update { $0.isVisible = true }
      tool = kind
      visible = true
      if let selectedID { recordPresentation(.marker(selectedID)) }
      editing = true
      return
    }
    guard markers.count < 100 else {
      error = "Keep at most 100 markers in a layout."
      return
    }
    var marker = DesignMarker(tool: kind, display: display)
    marker.x = min(160, screen.frame.width / 4)
    marker.y = min(160, screen.frame.height / 4)
    if kind == .guides {
      marker.width = screen.frame.width
      marker.height = screen.frame.height
    }
    if kind == .overlay {
      marker.width = min(960, screen.frame.width - 100)
      marker.height = min(640, screen.frame.height - 100)
      marker.columns = 12
      marker.spacing = 8
    }
    if kind == .screens {
      marker.width = 393
      marker.height = 852
      marker.safeAreas = true
      marker.topInset = 59
      marker.bottomInset = 34
    }
    markers.append(marker)
    selectedID = marker.id
    tool = kind
    visible = true
    editing = true
  }
  func duplicate() {
    guard var marker = selected, markers.count < 100 else { return }
    if marker.tool == .ruler && markers.filter({ $0.tool == .ruler }).count >= 2 { return }
    marker.id = UUID()
    marker.x += 20
    marker.y += 20
    markers.append(marker)
    selectedID = marker.id
  }
  func remove() {
    markers.removeAll { $0.id == selectedID }
    selectedID = markers.last?.id
  }
  func hide() {
    visible = false
    editing = false
    crosshair = false
    loupe = false
  }
  func saveColor() {
    guard let sample = colorSample else { return }
    if !swatches.contains(sample.hex) {
      swatches.append(sample.hex)
      swatches = Array(swatches.suffix(128))
    }
  }
  func copyColor() {
    guard colorSample != nil else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(colorValue, forType: .string)
  }
  func exportPalette(aco: Bool) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Schnaps Colors." + (aco ? "aco" : "json")
    if panel.runModal() == .OK, let url = panel.url {
      do {
        let data =
          aco
          ? ColorPalette.aco(swatches.compactMap(InspectorColor.init(hex:)))
          : try JSONEncoder().encode(swatches)
        try data.write(to: url, options: .atomic)
      } catch { self.error = error.localizedDescription }
    }
  }
  func clearPalette() {
    let alert = NSAlert()
    alert.messageText = "Clear Saved Colors?"
    alert.informativeText = "Export your palette first if you want to keep a copy."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Clear")
    if alert.runModal() == .alertSecondButtonReturn { swatches = [] }
  }
  func importPalette() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
      let values =
        try url.pathExtension.lowercased() == "aco"
        ? ColorPalette.readACO(data).map(\.hex) : JSONDecoder().decode([String].self, from: data)
      let valid = values.compactMap(InspectorColor.init(hex:)).map(\.hex)
      guard valid.count == values.count else {
        throw TextCodecError.invalid("Palette must contain six-digit RGB hex colors.")
      }
      swatches = Array(Set(swatches + valid).sorted().prefix(128))
    } catch { self.error = error.localizedDescription }
  }
  func exportLayout() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "Schnaps Layout.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do { try JSONEncoder().encode(markers).write(to: url, options: .atomic) } catch {
      self.error = error.localizedDescription
    }
  }
  func importLayout() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
      let decoded = try JSONDecoder().decode([DesignMarker].self, from: data)
      guard decoded.count <= 100 else { throw CocoaError(.fileReadCorruptFile) }
      markers = decoded.map {
        var item = $0
        item.id = UUID()
        item.validate()
        if !NSScreen.screens.contains(where: { Self.displayID($0) == item.display }),
          let main = NSScreen.main
        {
          item.display = Self.displayID(main)
        }
        item.imageName = nil
        item.attachedWindow = nil
        return item
      }
      selectedID = markers.first?.id
      visible = true
    } catch { self.error = error.localizedDescription }
  }
  static func displayID(_ screen: NSScreen) -> UInt32 {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
      ?? 0
  }
  static var imageFolder: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Schnaps/Overlay Images", isDirectory: true)
  }
  func chooseImage(clipboard: Bool = false) {
    var image: NSImage?
    if clipboard {
      image = NSImage(pasteboard: NSPasteboard.general)
    } else {
      let panel = NSOpenPanel()
      panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
      panel.allowsMultipleSelection = false
      guard panel.runModal() == .OK, let url = panel.url else { return }
      image = NSImage(contentsOf: url)
    }
    guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      cg.width <= 8192, cg.height <= 8192, cg.width * cg.height <= 32_000_000,
      let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    else {
      error = "Choose an image up to 32 megapixels and 8192 pixels per side."
      return
    }
    do {
      try FileManager.default.createDirectory(
        at: Self.imageFolder, withIntermediateDirectories: true)
      let name = UUID().uuidString + ".png"
      try data.write(to: Self.imageFolder.appendingPathComponent(name), options: .atomic)
      update {
        $0.imageName = name
        $0.width = Double(cg.width) / image.size.width > 1 ? image.size.width : Double(cg.width)
        $0.height = image.size.height
      }
    } catch { self.error = error.localizedDescription }
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(markers) { defaults.set(data, forKey: key) }
  }
}

@MainActor
final class DesignToolsController {
  let state = DesignTools.shared
  private var windows: [DesignPanel] = []
  private var ticker: Timer?
  private var captureTask: Task<Void, Never>?
  private var snapshots: [UInt32: ScreenSnapshot] = [:]
  private var lastCapture = Date.distantPast
  private var capturing = false
  private var lastWindowUpdate = Date.distantPast
  private var previousApp: NSRunningApplication?
  private var dismissingTool = false
  init() {
    state.redraw = { [weak self] in self?.synchronize() }
    state.show = { [weak self] tool in self?.activate(tool) }
    state.capture = { [weak self] copy in self?.captureSelected(copy: copy) }
    state.dismiss = { [weak self] in self?.dismissLastTool() }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.rebuild() }
    }
  }
  func activate(_ tool: DesignTool) {
    if tool == .loupe || tool == .crosshair {
      state.tool = tool
      if tool == .loupe {
        ScreenRecordingPermission.shared.refresh()
        guard ScreenRecordingPermission.shared.granted else {
          requestCapture()
          return
        }
        state.loupe.toggle()
      } else {
        state.crosshair.toggle()
      }
      state.editing = false
    } else {
      state.add(tool)
    }
    synchronize()
    if (tool == .loupe && state.loupe) || (tool == .crosshair && state.crosshair),
      let window = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
      previousApp = NSWorkspace.shared.frontmostApplication
      window.makeKey()
      window.makeFirstResponder(window.contentView)
    }
  }
  private func restorePreviousApplication() {
    guard let previousApp else { return }
    for window in windows where window.isKeyWindow { window.resignKey() }
    if previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp.activate(options: []) }
    self.previousApp = nil
  }
  private func dismissLastTool() {
    dismissingTool = true
    _ = state.dismissLastTool()
    dismissingTool = false
  }
  private func requestCapture() {
    let alert = NSAlert()
    alert.messageText = "Allow Screen Recording for Loupe"
    alert.informativeText =
      "Loupe reads screen pixels to magnify and sample colors. Other design markers work without access."
    alert.addButton(withTitle: ScreenRecordingPermission.shared.buttonTitle)
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn {
      if ScreenRecordingPermission.shared.hasRequested {
        ScreenRecordingPermission.shared.openSettings()
      } else {
        Task {
          await ScreenRecordingPermission.shared.request()
          if ScreenRecordingPermission.shared.granted { self.activate(.loupe) }
        }
      }
    }
  }
  private func rebuild() {
    for window in windows {
      window.orderOut(nil)
      window.close()
    }
    windows = []
    state.rehomeMissingDisplays()
    synchronize()
  }
  private func synchronize() {
    guard state.isActive else {
      for window in windows { window.orderOut(nil) }
      ticker?.invalidate()
      ticker = nil
      captureTask?.cancel()
      captureTask = nil
      snapshots = [:]
      state.colorSample = nil
      state.frozenLoupe = nil
      restorePreviousApplication()
      return
    }
    if windows.isEmpty {
      for screen in NSScreen.screens {
        let window = DesignPanel(
          contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
          backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.animationBehavior = .none
        let canvas = DesignCanvas(
          frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: state)
        canvas.snapshot = { [weak self] in self?.snapshots[DesignTools.displayID(screen)] }
        window.contentView = canvas
        windows.append(window)
      }
    }
    for window in windows {
      window.ignoresMouseEvents = !state.editing
      window.orderFrontRegardless()
      window.contentView?.needsDisplay = true
    }
    if state.editing,
      let window = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
      !window.isKeyWindow
    {
      previousApp = NSWorkspace.shared.frontmostApplication
      window.makeKey()
      window.makeFirstResponder(window.contentView)
    }
    if !state.editing && !dismissingTool { restorePreviousApplication() }
    if ticker == nil {
      ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.tick() }
      }
    }
  }
  private func tick() {
    let screenPreview =
      state.visible && state.markers.contains { $0.tool == .screens && $0.isVisible }
      && (state.vision != .normal || state.retinaPreview)
    if state.crosshair || state.loupe || screenPreview {
      for window in windows { window.contentView?.needsDisplay = true }
    }
    if Date().timeIntervalSince(lastWindowUpdate) > 0.5 {
      lastWindowUpdate = Date()
      followWindows()
    }
    let needsPixels =
      state.loupe || screenPreview
      || (state.crosshair && UserDefaults.standard.bool(forKey: PreferenceKey.autoContrast))
      || (state.editing && NSEvent.modifierFlags.contains(.control))
    guard needsPixels, !capturing, Date().timeIntervalSince(lastCapture) > 0.25,
      ScreenRecordingPermission.shared.granted
    else { return }
    capturing = true
    lastCapture = Date()
    captureTask = Task { [weak self] in
      defer { self?.capturing = false }
      do {
        let frames = try await ScreenSnapshot.capture()
        guard !Task.isCancelled, let self, self.state.isActive else { return }
        self.snapshots = frames
      } catch { /* A transient capture failure keeps the last frame. */  }
    }
  }
  private func followWindows() {
    guard state.visible,
      state.markers.contains(where: { $0.attachedWindow != nil && $0.isVisible }),
      ScreenRecordingPermission.shared.granted,
      let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { return }
    var result = state.markers
    for index in result.indices {
      guard result[index].isVisible, let id = result[index].attachedWindow,
        let info = list.first(where: {
          ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
        }),
        let dictionary = info[kCGWindowBounds as String] as? [String: Any],
        let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
      else { continue }
      let displays = NSScreen.screens.map { screen in
        let id = DesignTools.displayID(screen)
        return (id: id, bounds: CGDisplayBounds(id))
      }
      if let best = DesignGeometry.bestDisplay(for: rect, displays: displays) {
        result[index].display = best
      }
      let display = CGDisplayBounds(result[index].display)
      result[index].x = rect.minX - display.minX
      result[index].y = rect.minY - display.minY
      result[index].width = rect.width
      result[index].height = rect.height
      result[index].validate()
    }
    if result != state.markers { state.markers = result }
  }
  private func captureSelected(copy: Bool) {
    guard let marker = state.selected else { return }
    ScreenRecordingPermission.shared.refresh()
    guard ScreenRecordingPermission.shared.granted else {
      state.error = "Allow Screen Recording in Settings → Permissions to capture a marker."
      return
    }
    Task {
      do {
        let frames = try await ScreenSnapshot.capture()
        guard var snapshot = frames[marker.display] else {
          throw ScreenshotExport.ExportError.noCapture
        }
        if marker.tool == .screens, state.vision != .normal {
          let image = VisionRenderer.apply(snapshot.image, mode: state.vision)
          if let pixels = PixelBuffer(image: image) {
            snapshot = ScreenSnapshot(
              image: image, pixels: pixels, scaleX: snapshot.scaleX, scaleY: snapshot.scaleY)
          }
        }
        _ = try ScreenshotExport.export(
          snapshot: snapshot, region: marker.rect, copy: copy, togglePadding: false)
      } catch { state.error = error.localizedDescription }
    }
  }
}

final class DesignPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
