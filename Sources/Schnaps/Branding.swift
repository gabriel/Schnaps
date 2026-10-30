import AppKit

@MainActor
enum AppBranding {
    static func icon(dark: Bool) -> NSImage? {
        let name = dark ? "Schnaps-Mark-Dark" : "Schnaps-Mark"
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    private static var appearanceObservation: NSKeyValueObservation?

    static func installIcon() {
        // Let the system resolve the compiled Default, Dark and Mono icon renditions.
        if #available(macOS 26, *) { return }
        // ICNS has no automatic appearance selection on older macOS.
        updateLegacyDockIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in updateLegacyDockIcon() }
        }
    }

    private static func updateLegacyDockIcon() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let name = dark ? "Schnaps-Dark" : "Schnaps"
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns"),
              let dockIcon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = dockIcon
    }
}
