import AppKit
import SwiftUI
import Carbon
import Sparkle
import MeasurementCore

@main
struct SchnapsApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let settingsNavigation = SettingsNavigation()
    private let overlay = OverlayController()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var hotKeys: [EventHotKeyRef] = []
    private var shortcutWarning: String?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBranding.installIcon()
        UserDefaults.standard.register(defaults: [PreferenceKey.unit: "pt", PreferenceKey.tolerance: 18,
                                                  PreferenceKey.scrollTolerance: true,
                                                  PreferenceKey.showInDock: false,
                                                  PreferenceKey.defaultTool: MeasurementMode.findDimensions.rawValue])
        updateDockVisibility()
        NotificationCenter.default.addObserver(self, selector: #selector(updateDockVisibility),
                                               name: UserDefaults.didChangeNotification, object: nil)
        let tolerance = TolerancePreset.closest(to: UserDefaults.standard.integer(forKey: PreferenceKey.tolerance))
        UserDefaults.standard.set(tolerance.rawValue, forKey: PreferenceKey.tolerance)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Schnaps measurements")
        let menu = NSMenu()
        menu.addItem(item("Start Measuring", action: #selector(startDefaultTool), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Find Dimensions", action: #selector(findDimensions), key: "f"))
        menu.addItem(item("Measure Area", action: #selector(measureArea), key: "m"))
        menu.addItem(.separator())
        menu.addItem(toleranceMenuItem())
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(updateMenuItem())
        menu.addItem(.separator())
        menu.addItem(item("Quit Schnaps", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(item("About Schnaps", action: #selector(about), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        appMenu.addItem(toleranceMenuItem())
        appMenu.addItem(.separator())
        appMenu.addItem(updateMenuItem())
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Schnaps", action: #selector(quit), key: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
        updaterController.startUpdater()
        installHotKey()
        showSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if overlay.isActive { return true }
        showSettings()
        return true
    }

    @objc private func updateDockVisibility() {
        let policy: NSApplication.ActivationPolicy = UserDefaults.standard.bool(forKey: PreferenceKey.showInDock) ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if let settingsWindow, settingsWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func toleranceMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Color tolerance", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Color tolerance")
        menu.delegate = self
        for preset in TolerancePreset.allCases {
            let entry = item(preset.title, action: #selector(selectTolerance(_:)), key: "")
            entry.tag = preset.rawValue
            menu.addItem(entry)
        }
        menuNeedsUpdate(menu)
        parent.submenu = menu
        return parent
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let value = TolerancePreset.closest(to: UserDefaults.standard.integer(forKey: PreferenceKey.tolerance)).rawValue
        for entry in menu.items { entry.state = entry.tag == value ? .on : .off }
    }

    @objc private func selectTolerance(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: PreferenceKey.tolerance)
    }

    private func updateMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = updaterController
        return item
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc func startDefaultTool() {
        start(mode: MeasurementMode(rawValue: UserDefaults.standard.string(forKey: PreferenceKey.defaultTool) ?? "") ?? .findDimensions)
    }

    @objc private func findDimensions() { start(mode: .findDimensions) }
    @objc private func measureArea() { start(mode: .area) }

    private func start(mode: MeasurementMode) {
        if mode == .findDimensions && !CGPreflightScreenCaptureAccess() {
            showSettings()
            let alert = NSAlert()
            alert.messageText = "Allow Screen Recording to Find Dimensions"
            alert.informativeText = "Schnaps needs a still image of your screen to find edges. You can allow access in System Settings or measure an area manually."
            alert.addButton(withTitle: "Open Settings…")
            alert.addButton(withTitle: "Measure Area")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if !CGRequestScreenCaptureAccess() {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
                return
            }
            guard response == .alertSecondButtonReturn else { return }
            settingsWindow?.orderOut(nil)
            overlay.toggle(mode: .area)
            return
        }
        settingsWindow?.orderOut(nil)
        overlay.toggle(mode: mode)
    }

    @objc private func screensChanged() { overlay.stop() }
    @objc private func about() {
        settingsNavigation.pane = .about
        showSettings()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showSettings() {
        overlay.stop()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Schnaps Settings"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.minSize = NSSize(width: 720, height: 500)
            window.setFrameAutosaveName("SchnapSettings")
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(
                start: { [weak self] mode in self?.start(mode: mode) }, shortcutWarning: shortcutWarning,
                navigation: settingsNavigation, updates: UpdateSettings(updater: updaterController.updater)))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func installHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr else {
                return OSStatus(eventNotHandledErr)
            }
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
                    .start(mode: id.id == 2 ? .findDimensions : .area)
            }
            return noErr
        }, 1, &eventType, pointer, &handler)
        for (id, key) in [(UInt32(1), kVK_ANSI_M), (UInt32(2), kVK_ANSI_F)] {
            var hotKey: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(key), UInt32(cmdKey | shiftKey),
                                            EventHotKeyID(signature: 0x5343484E, id: id),
                                            GetApplicationEventTarget(), 0, &hotKey)
            if result == noErr, let hotKey { hotKeys.append(hotKey) }
            else { shortcutWarning = "A global shortcut is in use by another app. Use the Schnaps menu bar to activate the tool." }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
