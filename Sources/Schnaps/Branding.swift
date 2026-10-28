import AppKit

@MainActor
enum AppBranding {
    static var icon: NSImage? {
        guard let url = Bundle.main.url(forResource: "Schnaps-Mark", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func installIcon() {
        guard let url = Bundle.main.url(forResource: "Schnaps", withExtension: "icns"),
              let dockIcon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = dockIcon
    }

}
