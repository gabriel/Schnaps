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

}

@MainActor
final class ToolOverlayController: NSObject, NSWindowDelegate, NSPopoverDelegate {
    private let preferences = ToolOverlayPreferences()
    private var panel: NSPanel?
    private var inspectorButton: NSButton?
    private var inspector: NSPopover?
    private var terminating = false
    private var measurementActive = false
    var onVisibilityChanged: (() -> Void)?
    var measure: ((MeasurementMode) -> Void)?
    var activateTool: ((DesignTool) -> Void)?
    var showText: (() -> Void)?
    var beforeInspecting: (() -> Void)?
    var isEnabled: Bool { preferences.isEnabled }

    func restore() {
        if isEnabled { show() } else { inspector?.close(); panel?.orderOut(nil) }
    }
    func toggle() { setEnabled(!isEnabled) }
    func setEnabled(_ enabled: Bool) {
        preferences.isEnabled = enabled
        restore()
        onVisibilityChanged?()
    }
    func prepareToTerminate() { terminating = true }
    func windowWillClose(_ notification: Notification) {
        inspector?.close()
        guard !terminating else { return }
        preferences.isEnabled = false
        onVisibilityChanged?()
    }
    func measurementChanged(_ active: Bool) {
        measurementActive = active
        if active { inspector?.close() }
        panel?.level = paletteLevel
    }
    private var paletteLevel: NSWindow.Level {
        NSWindow.Level(rawValue: (measurementActive ? NSWindow.Level.screenSaver : .floating).rawValue + 1)
    }
    func inspect() {
        beforeInspecting?()
        setEnabled(true)
        guard let inspectorButton else { return }
        if inspector == nil {
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.animates = false
            popover.delegate = self
            popover.contentSize = NSSize(width: 440, height: 520)
            popover.contentViewController = NSHostingController(rootView:
                Form { ToolInspectorView() }.formStyle(.grouped).frame(width: 440, height: 520))
            inspector = popover
        }
        inspector?.show(relativeTo: inspectorButton.bounds, of: inspectorButton, preferredEdge: .minY)
        inspectorButton.state = .on
    }
    func popoverDidClose(_ notification: Notification) { inspectorButton?.state = .off }

    private func show() {
        if panel == nil {
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 4
            stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
            let handle = PaletteDragHandle()
            handle.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Move toolbar")
            handle.contentTintColor = .secondaryLabelColor
            handle.toolTip = "Drag to move toolbar"
            handle.setAccessibilityLabel("Move toolbar")
            handle.widthAnchor.constraint(equalToConstant: 14).isActive = true
            handle.heightAnchor.constraint(equalToConstant: 30).isActive = true
            stack.addArrangedSubview(handle)
            let titles = ["Find Dimensions", "Measure Area"] + DesignTool.allCases.map(\.rawValue)
                + ["Text Inspector", "Tool Inspector", "Hide Tool Overlay"]
            let symbols = ["arrow.up.left.and.arrow.down.right", "rectangle.dashed"] + DesignTool.allCases.map(\.symbol)
                + ["textformat", "slider.horizontal.3", "xmark"]
            for index in titles.indices {
                if index == 2 || index == titles.count - 2 {
                    let separator = NSBox()
                    separator.boxType = .separator
                    separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
                    separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
                    stack.addArrangedSubview(separator)
                }
                let button = NSButton(image: NSImage(systemSymbolName: symbols[index], accessibilityDescription: titles[index])!,
                                      target: self, action: #selector(performTool(_:)))
                button.tag = index
                button.imagePosition = .imageOnly
                button.bezelStyle = .recessed
                button.isBordered = false
                button.imageScaling = .scaleProportionallyDown
                button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: index == titles.count - 1 ? 12 : 17, weight: .regular)
                button.toolTip = titles[index]
                button.setAccessibilityLabel(titles[index])
                button.widthAnchor.constraint(equalToConstant: 30).isActive = true
                button.heightAnchor.constraint(equalToConstant: 30).isActive = true
                if index == titles.count - 2 { button.setButtonType(.pushOnPushOff); inspectorButton = button }
                stack.addArrangedSubview(button)
            }
            let material = NSVisualEffectView()
            material.material = .hudWindow
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = 10
            material.layer?.masksToBounds = true
            stack.translatesAutoresizingMaskIntoConstraints = false
            material.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: material.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: material.trailingAnchor),
                stack.topAnchor.constraint(equalTo: material.topAnchor),
                stack.bottomAnchor.constraint(equalTo: material.bottomAnchor)
            ])
            let size = stack.fittingSize
            let window = ToolPalettePanel(contentRect: NSRect(origin: .zero, size: size),
                                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "Schnaps Tools"
            window.setAccessibilityLabel("Schnaps Tools")
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.level = paletteLevel
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.delegate = self
            window.contentView = material
            window.center()
            // A new autosave name avoids restoring the old titled window's oversized frame.
            window.setFrameAutosaveName("SchnapsCompactToolPalette")
            _ = window.setFrameUsingName("SchnapsCompactToolPalette")
            window.setContentSize(size)
            if let visible = window.screen?.visibleFrame {
                window.setFrameOrigin(NSPoint(
                    x: max(visible.minX, min(window.frame.minX, visible.maxX - size.width)),
                    y: max(visible.minY, min(window.frame.minY, visible.maxY - size.height))))
            }
            panel = window
        }
        panel?.orderFrontRegardless()
    }
    @objc private func performTool(_ sender: NSButton) {
        switch sender.tag {
        case 0: measure?(.findDimensions)
        case 1: measure?(.area)
        case 2..<(2 + DesignTool.allCases.count): activateTool?(DesignTool.allCases[sender.tag - 2])
        case 2 + DesignTool.allCases.count: showText?()
        case 3 + DesignTool.allCases.count:
            if inspector?.isShown == true { inspector?.close() } else { inspect() }
        default: setEnabled(false)
        }
    }
}

/// Borderless panels still need to allow keyboard focus in their native popovers.
private final class ToolPalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) {
        if NSApp.currentEvent?.isARepeat != true { DesignTools.shared.dismiss?() }
    }
}

private final class PaletteDragHandle: NSImageView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
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
