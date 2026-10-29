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
    static let showInDock = "showInDock"
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case measurement = "Measurement"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"
    case about = "About Schnaps"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .measurement: "ruler"
        case .shortcuts: "keyboard"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var pane: SettingsPane? = .general
}

struct SettingsView: View {
    var start: (MeasurementMode) -> Void
    var shortcutWarning: String?
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var updates: UpdateSettings
    @StateObject private var membership = ProMembership()
    @AppStorage(PreferenceKey.unit) private var unit = MeasurementUnit.points.rawValue
    @AppStorage(PreferenceKey.tolerance) private var tolerance = TolerancePreset.medium.rawValue
    @AppStorage(PreferenceKey.scrollTolerance) private var scrollTolerance = true
    @AppStorage(PreferenceKey.defaultTool) private var defaultTool = MeasurementMode.findDimensions.rawValue
    @AppStorage(PreferenceKey.showInDock) private var showInDock = false
    @ObservedObject private var recordingPermission = ScreenRecordingPermission.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.pane) {
                ForEach(SettingsPane.allCases) { pane in
                    Label(pane.rawValue, systemImage: pane.symbol).tag(pane)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            Form {
                switch navigation.pane ?? .general {
                case .general: general
                case .measurement: measurement
                case .shortcuts: shortcuts
                case .permissions: permissions
                case .about: about
                }
            }
            .formStyle(.grouped)
            .navigationTitle((navigation.pane ?? .general).rawValue)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            recordingPermission.refresh()
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
                Toggle("Show in Dock", isOn: $showInDock)
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
                    ForEach(TolerancePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.title).tag(preset.rawValue)
                    }
                }
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
                shortcut("Change tolerance", "T / ⇧T")
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
            LabeledContent("Access", value: recordingPermission.granted ? "Allowed" : "Not allowed")
        } header: {
            Text("Screen Recording")
        } footer: {
            Button(recordingPermission.buttonTitle) {
                if recordingPermission.granted || recordingPermission.hasRequested {
                    recordingPermission.openSettings()
                } else {
                    Task { await recordingPermission.request() }
                }
            }
            .disabled(recordingPermission.requesting)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(.body)
        }
    }

    private var about: some View {
        Group {
            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Created by") {
                    Link("Gabriel Handford", destination: URL(string: "https://github.com/gabriel")!)
                }
            } header: {
                HStack(spacing: 12) {
                    if let icon = AppBranding.icon {
                        Image(nsImage: icon).resizable().scaledToFit().frame(width: 48, height: 48)
                            .accessibilityHidden(true)
                    }
                    Text("Schnaps").font(.title2).foregroundStyle(.primary)
                }
            } footer: {
                HStack(spacing: 16) {
                    Link("Website", destination: URL(string: "https://getschnaps.com")!)
                    Link("Source Code", destination: URL(string: "https://github.com/gabriel/Schnaps")!)
                }
                .font(.footnote)
                .padding(.top, -7)
            }
            Section {
                Toggle("Automatically check for updates", isOn: $updates.automaticallyChecksForUpdates)
                Toggle("Automatically download and install updates", isOn: $updates.automaticallyDownloadsUpdates)
                    .disabled(!updates.allowsAutomaticUpdates)
            } header: {
                Text("Updates")
            } footer: {
                Button("Check for Updates…", action: updates.checkForUpdates)
                    .disabled(!updates.canCheckForUpdates)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .font(.body)
            }
            ProSection(membership: membership)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) { Text(keys).foregroundStyle(.secondary) }
    }
}
