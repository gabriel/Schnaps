import AppKit
import SwiftUI
import MeasurementCore

/// Visibility is an explicit preference, independent of which tools are active.
struct ToolOverlayPreferences {
    var defaults: UserDefaults = .standard
    var isEnabled: Bool {
        get { defaults.bool(forKey: "showToolOverlay") }
        nonmutating set { if isEnabled != newValue { defaults.set(newValue, forKey: "showToolOverlay") } }
    }
    var inspectorExpanded: Bool {
        get { defaults.bool(forKey: "toolInspectorExpanded") }
        nonmutating set { if inspectorExpanded != newValue { defaults.set(newValue, forKey: "toolInspectorExpanded") } }
    }
}

@MainActor
final class ToolOverlayController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let preferences = ToolOverlayPreferences()
    private var panel: NSPanel?
    private var terminating = false
    private var measurementActive = false
    var onVisibilityChanged: (() -> Void)?
    var measure: ((MeasurementMode) -> Void)?
    var activateTool: ((DesignTool) -> Void)?
    var showText: (() -> Void)?
    var beforeInspecting: (() -> Void)?
    var isEnabled: Bool { preferences.isEnabled }

    func restore() {
        if isEnabled { show() } else { panel?.orderOut(nil) }
    }
    func toggle() { setEnabled(!isEnabled) }
    func setEnabled(_ enabled: Bool) {
        preferences.isEnabled = enabled
        restore()
        onVisibilityChanged?()
    }
    func prepareToTerminate() { terminating = true }
    func windowWillClose(_ notification: Notification) {
        guard !terminating else { return }
        preferences.isEnabled = false
        onVisibilityChanged?()
    }
    func measurementChanged(_ active: Bool) {
        guard measurementActive != active else { return }
        measurementActive = active
        resizeInspector()
        panel?.level = NSWindow.Level(rawValue: (active ? NSWindow.Level.screenSaver : .floating).rawValue + 1)
    }
    func inspect() {
        beforeInspecting?()
        preferences.inspectorExpanded = true
        setEnabled(true)
        resizeInspector()
        panel?.makeKeyAndOrderFront(nil)
    }
    private func show() {
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 1),
                                 styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            window.title = "Schnaps Tools"
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
            window.minSize = NSSize(width: 520, height: 60)
            window.delegate = self
            let toolbar = NSToolbar(identifier: "SchnapsToolOverlay")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.sizeMode = .small
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
            window.contentViewController = NSHostingController(rootView:
                Form { ToolInspectorView() }.formStyle(.grouped))
            window.center()
            window.setFrameAutosaveName("SchnapsToolOverlay")
            panel = window
            window.level = NSWindow.Level(rawValue: (measurementActive ? NSWindow.Level.screenSaver : .floating).rawValue + 1)
            resizeInspector()
        }
        panel?.orderFrontRegardless()
    }
    private func resizeInspector() {
        guard let panel else { return }
        let top = panel.frame.maxY
        let expanded = preferences.inspectorExpanded && !measurementActive
        panel.contentView?.isHidden = !expanded
        if expanded { panel.styleMask.insert(.resizable) } else { panel.styleMask.remove(.resizable) }
        panel.setContentSize(NSSize(width: max(520, panel.contentLayoutRect.width),
                                    height: expanded ? 540 : 1))
        let visible = (panel.screen ?? NSScreen.main)?.visibleFrame ?? panel.frame
        panel.setFrameOrigin(NSPoint(
            x: max(visible.minX, min(panel.frame.minX, visible.maxX - panel.frame.width)),
            y: max(visible.minY, min(top - panel.frame.height, visible.maxY - panel.frame.height))))
    }
    private var identifiers: [NSToolbarItem.Identifier] {
        (["find", "area"] + DesignTool.allCases.indices.map { "tool\($0)" } + ["text", "inspector"]).map { .init($0) }
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { identifiers }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { identifiers }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let index = identifiers.firstIndex(of: id) else { return nil }
        let titles = ["Find Dimensions", "Measure Area"] + DesignTool.allCases.map(\.rawValue) + ["Text Inspector", "Show or Hide Inspector"]
        let symbols = ["arrow.up.left.and.arrow.down.right", "rectangle.dashed"] + DesignTool.allCases.map(\.symbol) + ["textformat", "sidebar.right"]
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = titles[index]; item.toolTip = titles[index]
        item.image = NSImage(systemSymbolName: symbols[index], accessibilityDescription: titles[index])
        item.target = self; item.action = #selector(performTool(_:)); item.tag = index
        return item
    }
    @objc private func performTool(_ sender: NSToolbarItem) {
        switch sender.tag {
        case 0: measure?(.findDimensions)
        case 1: measure?(.area)
        case 2..<(2 + DesignTool.allCases.count): activateTool?(DesignTool.allCases[sender.tag - 2])
        case 2 + DesignTool.allCases.count: showText?()
        default:
            beforeInspecting?()
            preferences.inspectorExpanded.toggle()
            resizeInspector()
        }
    }
}

@MainActor
final class TextInspectorWindow {
    private var window: NSWindow?
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Text Inspector"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 540, height: 420)
            window.contentViewController = NSHostingController(rootView: Form { TextInspectorView() }.formStyle(.grouped))
            window.center()
            window.setFrameAutosaveName("SchnapsTextInspector")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
