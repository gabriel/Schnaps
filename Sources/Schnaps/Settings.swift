import AppKit
import SwiftUI
import MeasurementCore

enum MeasurementMode: String, CaseIterable {
    case area = "Measure Area"
    case findDimensions = "Find Dimensions"
}

enum PreferenceKey {
    static let unit = "measurementUnit"
    static let tolerance = "edgeTolerance"
    static let scrollTolerance = "scrollAdjustsTolerance"
    static let defaultTool = "defaultTool"
}

enum ColorTolerance {
    static let range = 0...100
    static func clamped(_ value: Int) -> Int { min(range.upperBound, max(range.lowerBound, value)) }
}

struct ToleranceSlider: View {
    @AppStorage(PreferenceKey.tolerance) private var tolerance = 18

    var body: some View {
        LabeledContent("Color tolerance") {
            HStack {
                Slider(value: Binding(get: { Double(tolerance) }, set: { tolerance = Int($0.rounded()) }),
                       in: Double(ColorTolerance.range.lowerBound)...Double(ColorTolerance.range.upperBound), step: 1)
                    .accessibilityLabel("Color tolerance")
                    .frame(width: 130)
                Text("\(tolerance)").monospacedDigit().frame(width: 28, alignment: .trailing)
            }
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case measurement = "Measurement"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .measurement: "ruler"
        case .shortcuts: "keyboard"
        case .permissions: "hand.raised"
        }
    }
}

struct SettingsView: View {
    var start: (MeasurementMode) -> Void
    var shortcutWarning: String?
    @State private var pane: SettingsPane? = .general
    @AppStorage(PreferenceKey.unit) private var unit = MeasurementUnit.points.rawValue
    @AppStorage(PreferenceKey.scrollTolerance) private var scrollTolerance = true
    @AppStorage(PreferenceKey.defaultTool) private var defaultTool = MeasurementMode.findDimensions.rawValue
    @State private var granted = CGPreflightScreenCaptureAccess()

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                ForEach(SettingsPane.allCases) { pane in
                    Label(pane.rawValue, systemImage: pane.symbol).tag(pane)
                }
                Button {
                    NSApp.orderFrontStandardAboutPanel(nil)
                } label: {
                    Label("About Schnaps", systemImage: "info.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            Form {
                switch pane ?? .general {
                case .general: general
                case .measurement: measurement
                case .shortcuts: shortcuts
                case .permissions: permissions
                }
            }
            .formStyle(.grouped)
            .navigationTitle((pane ?? .general).rawValue)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = CGPreflightScreenCaptureAccess()
        }
    }

    private var general: some View {
        Group {
            Section {
                LabeledContent("Find Dimensions") {
                    Button("Find Dimensions", action: { start(.findDimensions) })
                }
            } header: {
                Text("Tools")
            } footer: {
                Text("Move the pointer to measure distances between edges. Drag around an object to find its bounds.")
                    .font(.footnote)
                    .padding(.top, -7)
            }
            Section {
                LabeledContent("Measure Area") {
                    Button("Measure Area", action: { start(.area) })
                }
            } footer: {
                Text("Drag an exact rectangle, then move, resize, pin, or copy the measurement.")
                    .font(.footnote)
                    .padding(.top, -7)
            }
            Section("Activation") {
                Picker("Default tool", selection: $defaultTool) {
                    ForEach(MeasurementMode.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
        }
    }

    private var measurement: some View {
        Group {
            Section("Dimensions") {
                Picker("Units", selection: $unit) {
                    Text("Screen points (pt)").tag(MeasurementUnit.points.rawValue)
                    Text("Display pixels (px)").tag(MeasurementUnit.pixels.rawValue)
                }
            }
            Section {
                ToleranceSlider()
                Toggle("Scroll to adjust tolerance", isOn: $scrollTolerance)
            } header: {
                Text("Find Dimensions")
            } footer: {
                Text("Higher tolerance ignores subtle color differences and shadows.")
                    .font(.footnote)
                    .padding(.top, -7)
            }
        }
    }

    private var shortcuts: some View {
        Group {
            Section {
                shortcut("Find Dimensions", "⇧⌘F")
                shortcut("Measure Area", "⇧⌘M")
            } header: {
                Text("Global")
            } footer: {
                if let shortcutWarning { Text(shortcutWarning).font(.footnote).padding(.top, -7) }
            }
            Section("While Measuring") {
                shortcut("Copy dimensions", "Return / ⌘C")
                shortcut("Copy CSS", "⇧Return / ⇧⌘C")
                shortcut("Pin measurement", "Space")
                shortcut("Pin horizontal / vertical distance", "H / V")
                shortcut("Add horizontal / vertical guide", "⇧H / ⇧V")
                shortcut("Move selection", "Arrow keys")
                shortcut("Resize selection", "⌥Arrow keys")
                shortcut("Move or resize by ten units", "Add Shift")
                shortcut("Adjust tolerance in Find Dimensions", "Scroll up / down")
                shortcut("Switch units", "U")
                shortcut("Switch measurement tool", "S")
                shortcut("Refresh snapshot", "R")
                shortcut("Clear measurements", "⌘K")
                shortcut("Close overlay", "Escape")
            }
        }
    }

    private var permissions: some View {
        Section {
            LabeledContent("Access", value: granted ? "Allowed" : "Not allowed")
        } header: {
            Text("Screen Recording")
        } footer: {
            Button(granted ? "Open Screen Recording Settings…" : "Allow Screen Recording…") {
                if granted || !CGRequestScreenCaptureAccess() {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
                granted = CGPreflightScreenCaptureAccess()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(.body)
        }
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) { Text(keys).foregroundStyle(.secondary) }
    }
}
