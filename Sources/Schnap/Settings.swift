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
    static let defaultTool = "defaultTool"
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
    @AppStorage(PreferenceKey.tolerance) private var tolerance = 18
    @AppStorage(PreferenceKey.defaultTool) private var defaultTool = MeasurementMode.findDimensions.rawValue
    @State private var granted = CGPreflightScreenCaptureAccess()

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label(pane.rawValue, systemImage: pane.symbol).tag(pane)
            }
            .listStyle(.sidebar)
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
            }
            Section {
                LabeledContent("Measure Area") {
                    Button("Measure Area", action: { start(.area) })
                }
            } footer: {
                Text("Drag an exact rectangle, then move, resize, pin, or copy the measurement.")
                    .font(.footnote)
            }
            Section("Activation") {
                Picker("Default tool", selection: $defaultTool) {
                    ForEach(MeasurementMode.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
            Section {
                Button("About Schnap") { NSApp.orderFrontStandardAboutPanel(nil) }
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
                Picker("Color tolerance", selection: $tolerance) {
                    Text("Low (8)").tag(8)
                    Text("Medium (18)").tag(18)
                    Text("High (36)").tag(36)
                }
            } header: {
                Text("Find Dimensions")
            } footer: {
                Text("Higher tolerance ignores subtle color differences and shadows.")
                    .font(.footnote)
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
                if let shortcutWarning { Text(shortcutWarning).font(.footnote) }
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
                shortcut("Switch units", "U")
                shortcut("Switch measurement tool", "S")
                shortcut("Refresh snapshot", "R")
                shortcut("Clear measurements", "⌘K")
                shortcut("Close overlay", "Escape")
            }
        }
    }

    private var permissions: some View {
        Section("Screen Recording") {
            LabeledContent("Access", value: granted ? "Allowed" : "Not allowed")
            Button(granted ? "Open Screen Recording Settings…" : "Allow Screen Recording…") {
                if granted || !CGRequestScreenCaptureAccess() {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
                granted = CGPreflightScreenCaptureAccess()
            }
        }
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) { Text(keys).foregroundStyle(.secondary) }
    }
}
