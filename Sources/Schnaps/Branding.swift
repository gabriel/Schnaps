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
        updateApplicationIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in updateApplicationIcon() }
        }
    }

    /// Sparkle 2.10 reads NSImage.applicationIcon before consulting NSWorkspace.
    /// Refresh that process-local name from bundled artwork, bypassing stale
    /// Launch Services images without clearing system caches or replacing UI.
    static func registerApplicationImage(_ image: NSImage) {
        if let cached = NSImage(named: NSImage.applicationIconName), cached !== image {
            _ = cached.setName(nil)
        }
        _ = image.setName(NSImage.applicationIconName)
    }

    private static func updateApplicationIcon() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let name = dark ? "Schnaps-Dark" : "Schnaps"
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns"),
              let currentIcon = NSImage(contentsOf: url) else { return }
        registerApplicationImage(currentIcon)
        // Modern Dock appearances continue to come from Icon Composer.
        if #unavailable(macOS 26) { NSApp.applicationIconImage = currentIcon }
    }
}
