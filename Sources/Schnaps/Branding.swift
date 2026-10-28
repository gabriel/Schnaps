import AppKit

@MainActor
enum AppBranding {
    static var icon: NSImage? {
        guard let url = Bundle.main.url(forResource: "Schnaps", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func installIcon() {
        // Use the raw transparent artwork instead of Icon Services' legacy backplate.
        if let icon { NSApp.applicationIconImage = icon }
    }

    static func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let icon { options[.applicationIcon] = icon }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
