import AppKit

/// Native app windows temporarily opt this menu-bar app into the Dock and app menu.
@MainActor
final class AppWindow: NSWindow {
    override func makeKeyAndOrderFront(_ sender: Any?) {
        DockVisibility.update(including: self)
        if isMiniaturized { deminiaturize(sender) }
        NSApp.activate(ignoringOtherApps: true)
        super.makeKeyAndOrderFront(sender)
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        DockVisibility.update()
    }

    override func close() {
        super.close()
        // A closing window can still report itself as visible during AppKit callbacks.
        DockVisibility.update(excluding: self)
    }
}

@MainActor
enum DockVisibility {
    private static var updating = false

    static func policy(alwaysShow: Bool, windows: [NSWindow], including: NSWindow? = nil,
                       excluding: NSWindow? = nil) -> NSApplication.ActivationPolicy {
        let hasWindow = windows.contains {
            $0 !== excluding && $0 is AppWindow && ($0 === including || $0.isVisible || $0.isMiniaturized)
        } || (including is AppWindow && including !== excluding)
        return alwaysShow || hasWindow ? .regular : .accessory
    }

    static func update(including: NSWindow? = nil, excluding: NSWindow? = nil) {
        // Activation policy changes can synchronously emit defaults notifications.
        guard !updating else { return }
        updating = true
        defer { updating = false }
        let next = policy(alwaysShow: UserDefaults.standard.bool(forKey: PreferenceKey.showInDock),
                          windows: NSApp.windows, including: including, excluding: excluding)
        if NSApp.activationPolicy() != next { NSApp.setActivationPolicy(next) }
    }
}
