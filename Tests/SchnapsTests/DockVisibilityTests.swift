import AppKit
import Testing
@testable import Schnaps

@MainActor @Test func dockAppearsForNativeWindowsAndRemainsUntilLastOneCloses() {
    _ = NSApplication.shared
    let settings = AppWindow(contentRect: CGRect(x: 0, y: 0, width: 120, height: 80), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    let preview = AppWindow(contentRect: CGRect(x: 0, y: 0, width: 120, height: 80), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    settings.isReleasedWhenClosed = false
    preview.isReleasedWhenClosed = false
    defer { settings.close(); preview.close() }
    let windows = [settings, preview]
    #expect(DockVisibility.policy(alwaysShow: false, windows: windows) == .accessory)
    // Promote before the window is ordered on screen so its first activation has an app menu.
    #expect(DockVisibility.policy(alwaysShow: false, windows: windows, including: settings) == .regular)
    settings.orderFront(nil)
    preview.orderFront(nil)
    #expect(DockVisibility.policy(alwaysShow: false, windows: windows) == .regular)
    #expect(DockVisibility.policy(alwaysShow: false, windows: windows, excluding: settings) == .regular)
    preview.orderOut(nil)
    #expect(DockVisibility.policy(alwaysShow: false, windows: windows, excluding: settings) == .accessory)
    #expect(DockVisibility.policy(alwaysShow: true, windows: windows, excluding: settings) == .regular)
}

@MainActor @Test func dockIgnoresToolPanelsAndAlwaysShowWorksWithoutWindows() {
    _ = NSApplication.shared
    let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 120, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    defer { panel.close() }
    panel.orderFront(nil)
    #expect(DockVisibility.policy(alwaysShow: false, windows: [panel]) == .accessory)
    #expect(DockVisibility.policy(alwaysShow: false, windows: [panel], including: panel) == .accessory)
    #expect(DockVisibility.policy(alwaysShow: true, windows: []) == .regular)
    #expect(DockVisibility.policy(alwaysShow: false, windows: []) == .accessory)
}
