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
        // Use the transparent brand mark wherever we control the icon, including
        // the running Dock icon on macOS 26. System-owned surfaces may add chrome.
        updateDockIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in updateDockIcon() }
        }
    }

    private static func updateDockIcon() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard let dockIcon = icon(dark: dark) else { return }
        NSApp.applicationIconImage = dockIcon
    }
}
