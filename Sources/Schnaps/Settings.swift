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
    static let language = "appLanguage"
    static let roundPoints = "roundPoints"
    static let showMenuBar = "showMenuBar"
    static let clipboardFormat = "clipboardFormat"
    static let showUnits = "showMeasurementUnits"
    static let showIndicators = "showDimensionIndicators"
    static let showCursor = "showMeasurementCursor"
    static let aspectStyle = "aspectRatioStyle"
    static let aspectDistance = "aspectInDistanceTool"
    static let aspectArea = "aspectInAreaTool"
    static let snapGuides = "snapToGuides"
    static let snapObjects = "snapToSelectedObjects"
    static let freezeScreen = "freezeScreen"
    static let screenshotFormat = "screenshotFormat"
    static let screenshotScale = "screenshotScaleTo1x"
    static let screenshotSound = "screenshotSound"
    static let screenshotPadding = "screenshotPadding"
    static let screenshotFolder = "screenshotFolder"
    static let appearance = "appAppearance"
    static let animations = "interfaceAnimations"
    static let overlayColor = "overlayColor"
    static let alternativeColor = "alternativeColor"
    static let guideColor = "guideColor"
    static let autoContrast = "automaticContrast"
    static let selectedTolerance = "selectedTolerancePreset"
    static let toleranceZero = "toleranceZero"
    static let toleranceLow = "toleranceLow"
    static let toleranceMedium = "toleranceMedium"
    static let toleranceHigh = "toleranceHigh"

}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case screenshots = "Screenshots"
    case tolerance = "Tolerance"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"
    case about = "About Schnaps"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .screenshots: "camera"
        case .tolerance: "dial.low"
        case .appearance: "paintpalette"
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
    @Environment(\.colorScheme) private var colorScheme
    var shortcutWarning: String?
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var updates: UpdateSettings
    @StateObject private var membership = ProMembership()
    @StateObject private var loginItem = LoginItem()
    @State private var settingsError: String?
    @AppStorage(PreferenceKey.unit) private var unit = MeasurementUnit.points.rawValue
    @AppStorage(PreferenceKey.tolerance) private var tolerance = TolerancePreset.medium.rawValue
    @AppStorage(PreferenceKey.scrollTolerance) private var scrollTolerance = true
    @AppStorage(PreferenceKey.defaultTool) private var defaultTool = MeasurementMode.findDimensions.rawValue
    @AppStorage(PreferenceKey.showInDock) private var showInDock = false
    @AppStorage(PreferenceKey.language) private var language: String = "system"
    @AppStorage(PreferenceKey.roundPoints) private var roundedPoints: Bool = true
    @AppStorage(PreferenceKey.showMenuBar) private var showMenuBar: Bool = true
    @AppStorage(PreferenceKey.clipboardFormat) private var clipboardFormat: String = ClipboardFormat.widthHeight.rawValue
    @AppStorage(PreferenceKey.showUnits) private var showUnits: Bool = true
    @AppStorage(PreferenceKey.showIndicators) private var showIndicators: Bool = false
    @AppStorage(PreferenceKey.showCursor) private var showCursor: Bool = true
    @AppStorage(PreferenceKey.aspectStyle) private var aspectStyle: String = AspectRatioStyle.commonOnly.rawValue
    @AppStorage(PreferenceKey.aspectDistance) private var aspectDistance: Bool = false
    @AppStorage(PreferenceKey.aspectArea) private var aspectArea: Bool = true
    @AppStorage(PreferenceKey.snapGuides) private var snapGuides: Bool = true
    @AppStorage(PreferenceKey.snapObjects) private var snapObjects: Bool = true
    @AppStorage(PreferenceKey.freezeScreen) private var freezeScreen: Bool = true
    @AppStorage(PreferenceKey.screenshotFormat) private var screenshotFormat: String = "png"
    @AppStorage(PreferenceKey.screenshotScale) private var screenshotScale: Bool = false
    @AppStorage(PreferenceKey.screenshotSound) private var screenshotSound: Bool = true
    @AppStorage(PreferenceKey.screenshotPadding) private var screenshotPadding: Int = 0
    @AppStorage(PreferenceKey.screenshotFolder) private var screenshotFolder: String = NSHomeDirectory()+"/Desktop"
    @AppStorage(PreferenceKey.appearance) private var appearance: String = "system"
    @AppStorage(PreferenceKey.animations) private var animations: Bool = true
    @AppStorage(PreferenceKey.overlayColor) private var overlayColor: String = "FF375FFF"
    @AppStorage(PreferenceKey.alternativeColor) private var alternativeColor: String = "252525FF"
    @AppStorage(PreferenceKey.guideColor) private var guideColor: String = "0A84FFFF"
    @AppStorage(PreferenceKey.autoContrast) private var autoContrast: Bool = true
    @AppStorage(PreferenceKey.selectedTolerance) private var selectedTolerance: Int = TolerancePreset.medium.rawValue
    @AppStorage(PreferenceKey.toleranceZero) private var zero: Int = 0
    @AppStorage(PreferenceKey.toleranceLow) private var low: Int = 8
    @AppStorage(PreferenceKey.toleranceMedium) private var medium: Int = 18
    @AppStorage(PreferenceKey.toleranceHigh) private var high: Int = 36
    @ObservedObject private var recordingPermission = ScreenRecordingPermission.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.pane) {
                ForEach(SettingsPane.allCases) { pane in
                    Label(L(pane.rawValue), systemImage: pane.symbol).tag(pane)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            Form {
                switch navigation.pane ?? .general {
                case .general: general
                case .screenshots: screenshots
                case .tolerance: toleranceSettings
                case .appearance: appearanceSettings
                case .shortcuts: shortcuts
                case .permissions: permissions
                case .about: about
                }
            }
            .formStyle(.grouped)
            .navigationTitle(L((navigation.pane ?? .general).rawValue))
        }
        .id(language)
        .frame(minWidth: 720, minHeight: 480)
        .environment(\.locale, Locale(identifier: language == "system" ? Locale.current.identifier : language))
        .alert(L("Settings"), isPresented: Binding(get: { settingsError != nil || loginItem.error != nil }, set: { if !$0 { settingsError=nil; loginItem.error=nil } })) {
            Button(L("Done"), role: .cancel) { settingsError=nil; loginItem.error=nil }
        } message: { Text(settingsError ?? loginItem.error ?? "") }
        .onChange(of: selectedTolerance) { _, _ in syncTolerance() }
        .onChange(of: zero) { _, _ in syncTolerance() }
        .onChange(of: low) { _, _ in syncTolerance() }
        .onChange(of: medium) { _, _ in syncTolerance() }
        .onChange(of: high) { _, _ in syncTolerance() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
            recordingPermission.refresh()
        }
    }

    private var general: some View {
        Group {
            Section {
                Picker(L("Default tool"), selection: $defaultTool) {
                    ForEach(MeasurementMode.allCases, id: \.rawValue) { Text(L($0.rawValue)).tag($0.rawValue) }
                }
            } header: { Text(L("Tools")) } footer: {
                Text(L("Move the pointer to measure distances between edges. Drag around an object to find its bounds."))
                    .font(.footnote).padding(.top, -7)
            }
            Section(L("Language")) {
                Picker(L("Language"), selection: $language) {
                    Text(L("System Default")).tag("system")
                    Text(L("English")).tag("en"); Text(L("简体中文")).tag("zh-Hans")
                    Text(L("Español")).tag("es"); Text(L("Français")).tag("fr")
                    Text(L("Italiano")).tag("it"); Text(L("日本語")).tag("ja"); Text(L("Русский")).tag("ru")
                }
            }
            Section {
                Toggle(L("Start at login"), isOn: Binding(get: { loginItem.enabled || loginItem.needsApproval }, set: { loginItem.setEnabled($0) }))
                Toggle(L("Show in menu bar"), isOn: $showMenuBar)
                Toggle(L("Show in Dock"), isOn: $showInDock)
            } header: { Text(L("Activation")) } footer: {
                if loginItem.needsApproval {
                    Text(L("Approve Schnaps in System Settings → Login Items."))
                        .font(.footnote).padding(.top, -7)
                }
            }
            Section(L("Measurement")) {
                Picker(L("Retina measurements"), selection: retinaBinding) {
                    Text(L("Points")).tag("pt")
                    Text(L("Points (rounded)")).tag("rounded")
                    Text(L("Display pixels")).tag("px")
                }
                Picker(L("Clipboard format"), selection: $clipboardFormat) {
                    ForEach(ClipboardFormat.allCases, id: \.rawValue) { Text(L($0.title)).tag($0.rawValue) }
                }
                Toggle(L("Display units"), isOn: $showUnits)
                Toggle(L("Display width/height indicators"), isOn: $showIndicators)
                Toggle(L("Show cursor"), isOn: $showCursor)
            }
            Section(L("Aspect ratio")) {
                Picker(L("Aspect ratio"), selection: $aspectStyle) {
                    ForEach(AspectRatioStyle.allCases, id: \.rawValue) { Text(L($0.title)).tag($0.rawValue) }
                }
                Toggle(L("Show in Find Dimensions"), isOn: $aspectDistance)
                Toggle(L("Show in Measure Area"), isOn: $aspectArea)
            }
            Section(L("Distance tool")) {
                Toggle(L("Snap to guides"), isOn: $snapGuides)
                Toggle(L("Snap to selected objects"), isOn: $snapObjects)
            }
            Section { Toggle(L("Freeze screen"), isOn: $freezeScreen) } footer: {
                Text(L("Keep a still screen while measuring.")).font(.footnote).padding(.top, -7)
            }
        }
    }

    private var screenshots: some View {
        Group {
            Section(L("Export")) {
                LabeledContent(L("Export folder")) {
                    Button { chooseScreenshotFolder() } label: {
                        Label(URL(fileURLWithPath: screenshotFolder).lastPathComponent, systemImage: "folder")
                    }.help(screenshotFolder)
                }
                Picker(L("File format"), selection: $screenshotFormat) {
                    Text(L("PNG")).tag("png"); Text(L("JPEG")).tag("jpg")
                }
                Toggle(L("Scale Retina screenshots to 1x"), isOn: $screenshotScale)
                Toggle(L("Play sounds"), isOn: $screenshotSound)
            }
            Section {
                LabeledContent(L("Padding")) {
                    HStack {
                        Slider(value: Binding(get: { Double(screenshotPadding) }, set: { screenshotPadding=Int($0) }), in: 0...101, step: 1)
                            .accessibilityLabel(L("Padding"))
                        Text(screenshotPadding > 100 ? L("Auto") : "\(screenshotPadding) pt").monospacedDigit().frame(minWidth: 46, alignment: .trailing)
                    }.frame(maxWidth: 250)
                }
            } footer: {
                Text(L("Hold Option to toggle padding when capturing.")).font(.footnote).padding(.top,-7)
            }
        }
    }

    private var toleranceSettings: some View {
        Group {
            Section {
                toleranceRow("Zero", value: $zero)
                toleranceRow("Low", value: $low)
                toleranceRow("Medium", value: $medium)
                toleranceRow("High", value: $high)
            } footer: {
                Text(L("Higher tolerance ignores subtle color differences and shadows.")).font(.footnote).padding(.top,-7)
            }
            Section {
                Picker(L("Default tolerance"), selection: $selectedTolerance) {
                    ForEach(TolerancePreset.allCases, id: \.rawValue) { Text(L($0.title)).tag($0.rawValue) }
                }
                Toggle(L("Scroll to adjust tolerance"), isOn: $scrollTolerance)
            } footer: {
                Button(L("Restore Defaults")) { MeasurementPreferences.resetTolerance() }
                    .buttonStyle(.bordered).controlSize(.regular).font(.body)
            }
        }
    }

    private var appearanceSettings: some View {
        Group {
            Section(L("Interface")) {
                Picker(L("Appearance"), selection: $appearance) {
                    Text(L("System Appearance")).tag("system")
                    Text(L("Light")).tag("light"); Text(L("Dark")).tag("dark")
                }
                Toggle(L("Animations"), isOn: $animations)
            }
            Section {
                ColorPicker(L("Overlay color"), selection: colorBinding($overlayColor), supportsOpacity: false)
                ColorPicker(L("Alternative color"), selection: colorBinding($alternativeColor), supportsOpacity: false)
                Toggle(L("Auto contrast"), isOn: $autoContrast)
                ColorPicker(L("Guides color"), selection: colorBinding($guideColor), supportsOpacity: false)
            } header: { Text(L("Measurement colors")) } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Press X while measuring to switch colors."))
                    Button(L("Restore Defaults")) { MeasurementPreferences.resetAppearance() }
                        .buttonStyle(.bordered).controlSize(.regular).font(.body)
                }.font(.footnote).padding(.top,-7)
            }
        }
    }

    private var retinaBinding: Binding<String> {
        Binding(get: { unit == "px" ? "px" : roundedPoints ? "rounded" : "pt" }, set: {
            unit = $0 == "px" ? "px" : "pt"; if $0 != "px" { roundedPoints = $0 == "rounded" }
        })
    }
    private func colorBinding(_ value: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(nsColor: NSColor(schnapsHex: value.wrappedValue) ?? .controlAccentColor) },
                set: { value.wrappedValue=NSColor($0).schnapsHex })
    }
    private func toleranceRow(_ title: String, value: Binding<Int>) -> some View {
        LabeledContent(L(title)) {
            HStack {
                Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue=Int($0.rounded()) }), in: 0...100)
                    .accessibilityLabel(L(title))
                TextField(L(title), value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = min(100, max(0, $0)) }), format: .number.grouping(.never))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 50)
            }.frame(maxWidth: 260)
        }
        .accessibilityElement(children: .contain)
    }
    private func syncTolerance() {
        MeasurementPreferences.selectTolerance(TolerancePreset(rawValue: selectedTolerance) ?? .medium)
    }
    private func chooseScreenshotFolder() {
        let panel=NSOpenPanel(); panel.canChooseDirectories=true; panel.canChooseFiles=false
        panel.canCreateDirectories=true; panel.allowsMultipleSelection=false
        panel.directoryURL=URL(fileURLWithPath:screenshotFolder)
        if panel.runModal() == .OK, let url=panel.url { screenshotFolder=url.path }
    }
    private var shortcuts: some View {
        Group {
            Section {
                shortcut("Find Dimensions", "⇧⌘F")
                shortcut("Measure Area", "⇧⌘M")
            } header: {
                Text(L("Global"))
            } footer: {
                if let shortcutWarning { Text(shortcutWarning).font(.footnote).padding(.top, -7) }
            }
            Section("Design Tools · Global") {
                shortcut("Rulers / Guides / Frames", "⌃⌘R / ⌃⌘G / ⌃⌘B")
                shortcut("Design Overlay / Screens", "⌃⌘O / ⌃⌘S")
                shortcut("Loupe / Crosshair", "⌃⌘L / ⌃⌘X")
                shortcut("Edit on screen / Hide all", "⌃⌘E / ⌃⌘H")
                shortcut("Copy sampled color", "⌃⌘C")
            }
            Section("While Editing Design Tools") {
                shortcut("Move / move by ten points", "Arrows / ⇧Arrows")
                shortcut("Rotate ruler 1° / 5° / 0.1°", "⌥Arrows / ⇧⌥Arrows / ⌃⌥Arrows")
                shortcut("Next horizontal guide / vertical guide / frame", "H / V / F")
                shortcut("Set / reset crosshair origin", "O / R")
                shortcut("Pin loupe position", "Space")
                shortcut("Copy color / save swatch", "C / ⇧C")
                shortcut("Delete selected marker", "Delete")
                shortcut("Leave markers and return to work", "Escape")
            }
            Section(L("Screenshots")) {
                shortcut("Copy screenshot", "C")
                shortcut("Save screenshot", "P")
                shortcut("Toggle screenshot padding", "⌥C / ⌥P")
            }
            Section(L("While Measuring")) {
                shortcut("Switch colors", "X")
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
            LabeledContent(L("Access"), value: L(recordingPermission.granted ? "Allowed" : "Not allowed"))
        } header: {
            Text(L("Screen Recording"))
        } footer: {
            Button(L(recordingPermission.buttonTitle)) {
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
                LabeledContent(L("Version"), value: appVersion)
                LabeledContent(L("Created by")) {
                    Link("Gabriel Handford", destination: URL(string: "https://github.com/gabriel")!)
                }
            } header: {
                HStack(spacing: 12) {
                    if let icon = AppBranding.icon(dark: colorScheme == .dark) {
                        Image(nsImage: icon).resizable().scaledToFit().frame(width: 48, height: 48)
                            .accessibilityHidden(true)
                    }
                    Text(L("Schnaps")).font(.title2).foregroundStyle(.primary)
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
                Picker("Channel", selection: $updates.channel) {
                    ForEach(UpdateChannel.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                }
                .disabled(!updates.canCheckForUpdates)
                Toggle("Automatically check for updates", isOn: $updates.automaticallyChecksForUpdates)
                Toggle("Automatically download and install updates", isOn: $updates.automaticallyDownloadsUpdates)
                    .disabled(!updates.allowsAutomaticUpdates)
            } header: {
                Text(L("Updates"))
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if updates.channel == .beta {
                        Text("Early builds. Stable resumes with the next newer stable release.")
                            .font(.footnote).padding(.top, -7)
                    }
                    Button("Check for Updates…", action: updates.checkForUpdates)
                        .disabled(!updates.canCheckForUpdates)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .font(.body)
                }
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
        LabeledContent(L(title)) { Text(keys).foregroundStyle(.secondary) }
    }
}
