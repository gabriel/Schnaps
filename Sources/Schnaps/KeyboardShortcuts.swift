import AppKit
import Carbon
import Combine
import SwiftUI

struct ShortcutBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt
    var key: String
    var enabled = true
    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }
    var carbonModifiers: UInt32 {
        UInt32((flags.contains(.command) ? cmdKey : 0) | (flags.contains(.control) ? controlKey : 0)
            | (flags.contains(.option) ? optionKey : 0) | (flags.contains(.shift) ? shiftKey : 0))
    }
    var label: String {
        guard enabled else { return "None" }
        return (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + key.uppercased()
    }
    static func make(_ keyCode: Int, _ key: String, _ flags: NSEvent.ModifierFlags) -> Self {
        Self(keyCode: UInt32(keyCode), modifiers: flags.rawValue, key: key)
    }
}

enum ShortcutAction: UInt32, CaseIterable, Identifiable {
    case area = 1, dimensions, ruler, guides, frames, overlay, screens, loupe, crosshair, edit, hide, copyColor
    var id: UInt32 { rawValue }
    var title: String {
        switch self {
        case .area: "Measure Area"
        case .dimensions: "Find Dimensions"
        case .ruler: "Rulers"
        case .guides: "Guides"
        case .frames: "Frames"
        case .overlay: "Design Overlay"
        case .screens: "Screens"
        case .loupe: "Loupe"
        case .crosshair: "Crosshair"
        case .edit: "Edit on Screen"
        case .hide: "Hide Design Tools"
        case .copyColor: "Copy Sampled Color"
        }
    }
    var defaultBinding: ShortcutBinding {
        let codes = [kVK_ANSI_M, kVK_ANSI_F, kVK_ANSI_R, kVK_ANSI_G, kVK_ANSI_B, kVK_ANSI_O,
                     kVK_ANSI_S, kVK_ANSI_L, kVK_ANSI_X, kVK_ANSI_E, kVK_ANSI_H, kVK_ANSI_C]
        let keys = ["m", "f", "r", "g", "b", "o", "s", "l", "x", "e", "h", "c"]
        let index = Int(rawValue) - 1
        return .make(codes[index], keys[index], rawValue <= 2 ? [.command, .shift] : [.command, .control])
    }
}

@MainActor
final class ShortcutSettings: ObservableObject {
    static let shared = ShortcutSettings()
    static let preferenceKey = "keyboardShortcuts.v1"
    private let defaults: UserDefaults
    @Published private var overrides: [String: ShortcutBinding]
    @Published var registrationErrors: [String] = []
    var onChange: (() -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    var checkAvailability: ((ShortcutBinding) -> Bool)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overrides = defaults.data(forKey: Self.preferenceKey).flatMap {
            try? JSONDecoder().decode([String: ShortcutBinding].self, from: $0)
        } ?? [:]
    }
    func binding(for action: ShortcutAction) -> ShortcutBinding {
        overrides[String(action.rawValue)] ?? action.defaultBinding
    }
    func validationError(_ binding: ShortcutBinding, for action: ShortcutAction) -> String? {
        guard binding.enabled else { return nil }
        let flags = binding.flags.intersection([.command, .control, .option, .shift])
        guard binding.keyCode < 128, binding.key.count == 1,
              !binding.key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !flags.intersection([.command, .control, .option]).isEmpty else {
            return "Use a letter, number, or symbol with Command, Control, or Option."
        }
        let key = binding.key.lowercased()
        if (flags == .command && ["q", ",", "h", " ", "c", "v", "x", "a", "z", "f", "g"].contains(key))
            || (flags == [.command, .shift] && ["z", "g"].contains(key)) {
            return "This shortcut is reserved by macOS or Schnaps."
        }
        if let duplicate = ShortcutAction.allCases.first(where: {
            let other = self.binding(for: $0)
            return $0 != action && other.enabled && other.keyCode == binding.keyCode && other.modifiers == binding.modifiers
        }) { return "Already used by \(duplicate.title)." }
        return nil
    }
    @discardableResult func set(_ binding: ShortcutBinding, for action: ShortcutAction) -> String? {
        if let error = validationError(binding, for: action) { return error }
        if binding.enabled && checkAvailability?(binding) == false { return "This shortcut is in use by macOS or another app." }
        overrides[String(action.rawValue)] = binding
        persist()
        return nil
    }
    func reset() { overrides.removeAll(); persist() }
    private func persist() {
        defaults.set(try? JSONEncoder().encode(overrides), forKey: Self.preferenceKey)
        onChange?()
    }
}

struct ShortcutEditor: View {
    @ObservedObject private var settings = ShortcutSettings.shared
    @State private var recording: ShortcutAction?
    var body: some View {
        Section {
            ForEach([ShortcutAction.dimensions, .area]) { row($0) }
        } header: { Text("Global") } footer: {
            Text("Click a shortcut to change it. Changes apply immediately and are saved.")
                .font(.footnote).padding(.top, -7)
        }
        Section("Design Tools · Global") {
            ForEach(ShortcutAction.allCases.filter { $0.rawValue > 2 }) { row($0) }
        }
        Section {
            Button("Restore Default Shortcuts") { settings.reset() }
        } footer: {
            if !settings.registrationErrors.isEmpty {
                Text(settings.registrationErrors.joined(separator: "\n")).font(.footnote).padding(.top, -7)
            }
        }
        .sheet(item: $recording, onDismiss: { settings.onRecordingChanged?(false) }) { action in
            ShortcutRecordingSheet(action: action, settings: settings) { recording = nil }
        }
    }
    private func row(_ action: ShortcutAction) -> some View {
        LabeledContent(L(action.title)) {
            Button(settings.binding(for: action).label) {
                settings.onRecordingChanged?(true)
                recording = action
            }
            .monospaced().accessibilityLabel("Change \(action.title) shortcut")
            .accessibilityValue(settings.binding(for: action).label)
        }
    }
}

private struct ShortcutRecordingSheet: View {
    let action: ShortcutAction
    @ObservedObject var settings: ShortcutSettings
    var close: () -> Void
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action.title).font(.headline)
            Text("Press a new shortcut.")
            Text("Use Command, Control, or Option with a letter, number, or symbol.").font(.footnote).foregroundStyle(.secondary)
            ShortcutKeyCapture { event in
                if event.keyCode == kVK_Escape { close(); return }
                guard !event.isARepeat else { return }
                let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
                let binding = ShortcutBinding(keyCode: UInt32(event.keyCode), modifiers: flags.rawValue,
                                              key: event.charactersIgnoringModifiers?.lowercased() ?? "")
                if let message = settings.set(binding, for: action) { error = message } else { close() }
            }.frame(height: 1).accessibilityHidden(true)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            HStack {
                Button("Clear Shortcut") {
                    var binding = settings.binding(for: action); binding.enabled = false
                    _ = settings.set(binding, for: action); close()
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 380)
    }
}

private struct ShortcutKeyCapture: NSViewRepresentable {
    var record: (NSEvent) -> Void
    func makeNSView(context: Context) -> KeyView { let view = KeyView(); view.record = record; return view }
    func updateNSView(_ view: KeyView, context: Context) { view.record = record }
    final class KeyView: NSView {
        var record: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self) }
        }
        override func keyDown(with event: NSEvent) { record?(event) }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self else { return false }
            record?(event); return true
        }
    }
}
