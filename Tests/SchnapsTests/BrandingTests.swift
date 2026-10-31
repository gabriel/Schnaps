import AppKit
import Testing
@testable import Schnaps

@MainActor @Test func applicationImageReplacesStaleCacheAndFollowsAppearanceChanges() throws {
    let original = NSImage(named: NSImage.applicationIconName)
    _ = original?.setName(nil)
    defer {
        _ = NSImage(named: NSImage.applicationIconName)?.setName(nil)
        _ = original?.setName(NSImage.applicationIconName)
    }
    let stale = NSImage(size: NSSize(width: 16, height: 16))
    #expect(stale.setName(NSImage.applicationIconName))
    #expect(NSImage(named: NSImage.applicationIconName) === stale)
    let light = NSImage(size: NSSize(width: 32, height: 32))
    AppBranding.registerApplicationImage(light)
    #expect(NSImage(named: NSImage.applicationIconName) === light)
    #expect(stale.name() == nil)
    let dark = NSImage(size: NSSize(width: 64, height: 64))
    AppBranding.registerApplicationImage(dark)
    #expect(NSImage(named: NSImage.applicationIconName) === dark)
    #expect(light.name() == nil)
    AppBranding.registerApplicationImage(dark) // Reapplying must keep the named entry intact.
    #expect(NSImage(named: NSImage.applicationIconName) === dark)
}
