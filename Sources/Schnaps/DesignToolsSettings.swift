import AppKit
import MeasurementCore
import SwiftUI

struct DesignToolsSettings: View {
  @ObservedObject var tools = DesignTools.shared
  @State private var preset = ScreenTemplate.presets[3].name
  @State private var breakpoint = 960.0
  private func field(_ title: String, _ key: WritableKeyPath<DesignMarker, Double>) -> some View {
    TextField(
      title,
      value: Binding(
        get: { tools.selected?[keyPath: key] ?? 0 },
        set: { value in tools.update { $0[keyPath: key] = value } }),
      format: .number.grouping(.never)
    )
    .multilineTextAlignment(.trailing)
  }
  private func toggle(_ title: String, _ key: WritableKeyPath<DesignMarker, Bool>) -> some View {
    Toggle(
      title,
      isOn: Binding(
        get: { tools.selected?[keyPath: key] ?? false },
        set: { value in tools.update { $0[keyPath: key] = value } }))
  }
  var body: some View {
    Section {
      Picker("Tool", selection: $tools.tool) {
        ForEach(DesignTool.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
      }
      Button(
        tools.tool == .crosshair || tools.tool == .loupe
          ? "Toggle \(tools.tool.rawValue)" : "Add \(tools.tool.rawValue)"
      ) { tools.show?(tools.tool) }
      Toggle("Show design markers", isOn: $tools.visible)
      Toggle("Edit on screen", isOn: $tools.editing).disabled(!tools.isActive)
      Button("Hide All", action: tools.hide)
      Button("Image & Window Preview…") { ImagePreview.shared.show() }
      Button("Responsive Web Preview…") { BrowserPreview.shared.show() }
    } header: {
      Text("Design tools")
    } footer: {
      Text(
        "Drag to move. Drag a ruler’s end to rotate; hold Shift for 45°. Control snaps to detected edges. Escape leaves markers visible and lets clicks pass through."
      ).font(.footnote).padding(.top, -7)
    }
    if tools.tool == .loupe {
      loupe
    } else if tools.tool == .crosshair {
      crosshair
    } else {
      markerSettings
    }
    Section("Layouts") {
      HStack {
        Button("Save Layout…", action: tools.exportLayout)
        Button("Load Layout…", action: tools.importLayout)
      }
    }
    if let error = tools.error {
      Section {
        Text(error).foregroundStyle(.red)
        Button("Dismiss") { tools.error = nil }
      }
    }
  }
  @ViewBuilder private var markerSettings: some View {
    Section("Markers") {
      Picker("Selected marker", selection: $tools.selectedID) {
        Text("None").tag(UUID?.none)
        ForEach(Array(tools.markers.enumerated()), id: \.element.id) { index, marker in
          Text("\(index+1). \(marker.tool.rawValue)").tag(Optional(marker.id))
        }
      }
      HStack {
        Button("Duplicate", action: tools.duplicate).disabled(tools.selected == nil)
        Button("Remove", action: tools.remove).disabled(tools.selected == nil)
      }
    }
    if let marker = tools.selected {
      Section("Position") {
        Picker(
          "Display",
          selection: Binding(
            get: { marker.display }, set: { id in tools.update { $0.display = id } })
        ) {
          ForEach(NSScreen.screens, id: \.self) { screen in
            Text(screen.localizedName).tag(DesignTools.displayID(screen))
          }
        }
        field("X (pt)", \.x)
        field("Y (pt)", \.y)
        toggle("Show marker", \.isVisible)
        toggle("Lock position", \.locked)
        Toggle("Move matching markers together", isOn: $tools.linked)
      }
      if marker.tool == .ruler {
        Section("Ruler") {
          field("Length (pt)", \.width)
          field("Angle (°)", \.angle)
          field("Scale", \.scale)
          toggle("Calipers", \.calipers)
          toggle("Square extension", \.square)
          field("Extension length (pt)", \.height)
          toggle("Fraction and golden ratio marks", \.marks)
          Toggle("Synchronize lengths", isOn: $tools.synchronizeLength)
          Toggle("Synchronize angles", isOn: $tools.synchronizeAngle)
          Button("Rotate 90°") { tools.update { $0.angle += 90 } }
        }
      } else if marker.tool == .guides {
        Section("Guide") { toggle("Vertical", \.vertical) }
      } else {
        Section("Size") {
          field("Width (pt)", \.width)
          field("Height (pt)", \.height)
          field("Aspect ratio (0 = free)", \.aspectRatio)
          HStack {
            Button("Portrait / Landscape") {
              tools.update { m in
                let width = m.width
                m.width = m.height
                m.height = width
              }
            }
            Button("Center on Display") {
              if let screen = NSScreen.screens.first(where: {
                DesignTools.displayID($0) == marker.display
              }) {
                tools.update {
                  $0.x = (screen.frame.width - $0.width) / 2
                  $0.y = (screen.frame.height - $0.height) / 2
                }
              }
            }
          }
        }
        if marker.tool == .screens { screens }
        if marker.tool == .overlay { overlay }
        Section("Grid") {
          Stepper(
            "Columns: \(marker.columns)",
            value: Binding(get: { marker.columns }, set: { v in tools.update { $0.columns = v } }),
            in: 1...64)
          Stepper(
            "Rows: \(marker.rows)",
            value: Binding(get: { marker.rows }, set: { v in tools.update { $0.rows = v } }),
            in: 1...64)
          field("Margin (pt)", \.margin)
          field("Gutter (pt)", \.gutter)
          field("Baseline spacing (pt)", \.spacing)
          toggle("Center alignment marks", \.marks)
          Text(
            "Column width: \(DesignGeometry.columnWidth(width:marker.width,columns:marker.columns,margin:marker.margin,gutter:marker.gutter),format:.number.precision(.fractionLength(1))) pt"
          ).foregroundStyle(.secondary)
        }
        Section("Capture") {
          HStack {
            Button("Copy Screenshot") { tools.capture?(true) }
            Button("Save Screenshot") { tools.capture?(false) }
          }
        }
      }
      Section("Style") {
        LabeledContent("Opacity") {
          Slider(
            value: Binding(get: { marker.opacity }, set: { v in tools.update { $0.opacity = v } }),
            in: 0.05...1)
        }
        ColorPicker(
          "Marker color",
          selection: Binding(
            get: { Color(nsColor: NSColor(schnapsHex: marker.color) ?? .systemBlue) },
            set: { color in
              guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
              let hex = String(
                format: "%02X%02X%02XFF", Int((rgb.redComponent * 255).rounded()),
                Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
              tools.update { $0.color = hex }
            }), supportsOpacity: false)
      }
    }
  }
  private var screens: some View {
    Section("Screen template") {
      Picker("Device", selection: $preset) {
        ForEach(ScreenTemplate.presets) { Text($0.name).tag($0.name) }
      }
      Button("Apply Template") {
        if let device = ScreenTemplate.presets.first(where: { $0.name == preset }) {
          tools.update {
            $0.aspectRatio = 0
            $0.width = device.width
            $0.height = device.height
            $0.topInset = device.top
            $0.bottomInset = device.bottom
          }
        }
      }
      toggle("Title and action safe areas", \.safeAreas)
      field("Top inset (pt)", \.topInset)
      field("Bottom inset (pt)", \.bottomInset)
      field("Left inset (pt)", \.leftInset)
      field("Right inset (pt)", \.rightInset)
      field("Keyboard height (pt)", \.keyboardHeight)
      Toggle("Simulate 1× display", isOn: $tools.retinaPreview)
      Picker("Vision preview", selection: $tools.vision) {
        ForEach(VisionSimulation.allCases) { Text($0.rawValue).tag($0) }
      }
    }
  }
  @ViewBuilder private var overlay: some View {
    Section("Window") {
      Button("Refresh Windows", action: tools.refreshWindows)
      Picker(
        "Follow window",
        selection: Binding(
          get: { tools.selected?.attachedWindow },
          set: { value in tools.update { $0.attachedWindow = value } })
      ) {
        Text("Independent").tag(UInt32?.none)
        ForEach(tools.availableWindows) { Text($0.title).tag(Optional($0.id)) }
      }
      Button("Open Responsive Preview…") { BrowserPreview.shared.show() }
    }
    Section("Mockup") {
      HStack {
        Button("Choose Image…") { tools.chooseImage() }
        Button("Paste Image") { tools.chooseImage(clipboard: true) }
      }
      Button("Remove Image") { tools.update { $0.imageName = nil } }
      Picker("Breakpoint", selection: $breakpoint) {
        ForEach([320.0, 375, 393, 768, 960, 1024, 1280, 1440], id: \.self) {
          Text("\(Int($0)) pt").tag($0)
        }
      }
      Button("Apply Breakpoint") {
        if tools.selected?.attachedWindow != nil {
          tools.resizeAttachedWindow(width: breakpoint)
        } else {
          tools.update { $0.width = breakpoint }
        }
      }
      Button("Next Breakpoint") {
        let sizes = [320.0, 375, 393, 768, 960, 1024, 1280, 1440]
        breakpoint = sizes.first(where: { $0 > breakpoint }) ?? sizes[0]
        if tools.selected?.attachedWindow != nil {
          tools.resizeAttachedWindow(width: breakpoint)
        } else {
          tools.update { $0.width = breakpoint }
        }
      }
    }
  }
  private var crosshair: some View {
    Section {
      Toggle(
        "Crosshair", isOn: Binding(get: { tools.crosshair }, set: { _ in tools.show?(.crosshair) }))
      LabeledContent("Line width") { Slider(value: $tools.lineWidth, in: 1...8) }
      Button("Reset Origin") { tools.relativeOrigin = nil }
    } header: {
      Text("Coordinates")
    } footer: {
      Text(
        "While editing, click to set a relative origin. O sets the origin at the pointer; R resets it. Coordinates use the top-left of each display."
      ).font(.footnote).padding(.top, -7)
    }
  }
  private var loupe: some View {
    Group {
      Section("Loupe") {
        Toggle("Loupe", isOn: Binding(get: { tools.loupe }, set: { _ in tools.show?(.loupe) }))
        LabeledContent("Magnification") { Slider(value: $tools.zoom, in: 2...32) }
        Toggle("Pixel grid", isOn: $tools.pixelGrid)
        Picker("Color format", selection: $tools.colorFormat) {
          ForEach(
            ["Hex", "Short hex", "RGB", "HSL", "HSB", "Lab", "Swift", "SwiftUI", "UIColor"],
            id: \.self
          ) { Text($0).tag($0) }
        }
        LabeledContent("Sample", value: tools.colorValue).textSelection(.enabled)
        Picker("Reference color format", selection: $tools.referenceFormat) {
          ForEach(["Hex", "RGB", "HSL", "HSB", "Lab"], id: \.self) { Text($0).tag($0) }
        }
        LabeledContent("Reference value", value: tools.referenceColor).textSelection(.enabled)
        HStack {
          Button("Copy Color", action: tools.copyColor)
          Button("Save Swatch", action: tools.saveColor)
        }
        Button("Set Contrast Reference") { tools.contrastSample = tools.colorSample }
        LabeledContent("Contrast ratio", value: tools.contrast)
        Picker("Vision preview", selection: $tools.vision) {
          ForEach(VisionSimulation.allCases) { Text($0.rawValue).tag($0) }
        }
      }
      Section("Palette") {
        ForEach(tools.swatches, id: \.self) { hex in
          LabeledContent {
            Button(hex) {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(hex, forType: .string)
            }
          } label: {
            Color(nsColor: NSColor(schnapsHex: hex + "FF") ?? .clear).frame(width: 24, height: 16)
              .accessibilityLabel(hex)
          }
        }
        HStack {
          Button("Import Palette…", action: tools.importPalette)
          Button("Export JSON…") { tools.exportPalette(aco: false) }
          Button("Export ACO…") { tools.exportPalette(aco: true) }
          Button("Clear…", action: tools.clearPalette)
        }

      }
    }
  }
}
