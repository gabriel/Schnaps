import AppKit
import SwiftUI
import Carbon
import Sparkle
import MeasurementCore

@main
struct SchnapsApp {
    @MainActor static func main() {
        if TextCommandLine.runIfRequested() { return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var applyingPreferences = false
    private var settingsWindow: NSWindow?
    private let settingsNavigation = SettingsNavigation()
    private let recordingPermission = ScreenRecordingPermission.shared
    private let overlay = OverlayController()
    private let designTools = DesignToolsController()
    private let toolOverlay = ToolOverlayController()
    private let textInspector = TextInspectorWindow()
    private var toolOverlayMenuItems: [NSMenuItem] = []
    private let updateChannels = UpdateChannelSettings()
    private lazy var updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: updateChannels, userDriverDelegate: nil)
    private var hotKeys: [EventHotKeyRef] = []
    private var shortcutWarning: String?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBranding.installIcon()
        AppFonts.install()
        UserDefaults.standard.register(defaults: MeasurementPreferences.defaults)
        MeasurementPreferences.selectTolerance(MeasurementPreferences.selectedTolerance)
        updateDockVisibility()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Schnaps measurements")
        toolOverlay.measure = { [weak self] in self?.start(mode: $0) }
        toolOverlay.activateTool = { [weak self] in self?.activateDesignTool($0) }
        toolOverlay.showText = { [weak self] in self?.showTextTools() }
        toolOverlay.beforeInspecting = { [weak self] in
            self?.overlay.stop()
            DesignTools.shared.editing = false
        }
        toolOverlay.onVisibilityChanged = { [weak self] in self?.updateToolOverlayMenu() }
        overlay.onActivationChanged = { [weak self] in self?.toolOverlay.measurementChanged($0) }
        buildMenus()
        toolOverlay.restore()
        // Creating a status item can synchronously change its autosaved visibility defaults.
        // Observe only once the item and menus are ready.
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        preferencesChanged()
        updaterController.startUpdater()
        installHotKey()
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = launchEvent?.eventID == kAEOpenApplication
            && launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin && !toolOverlay.isEnabled { showSettings() }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private var menuLanguage: String?

    private func buildMenus() {
        guard let statusItem else { return }
        toolOverlayMenuItems.removeAll()
        let menu = NSMenu()
        menu.addItem(item("Start Measuring", action: #selector(startDefaultTool), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Find Dimensions", action: #selector(findDimensions), key: "f", modifiers: [.command, .shift]))
        menu.addItem(item("Measure Area", action: #selector(measureArea), key: "m", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(toolOverlayMenuItem())
        menu.addItem(designToolsMenu())
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
        appMenu.addItem(toolOverlayMenuItem())
        appMenu.addItem(designToolsMenu())
        appMenu.addItem(toleranceMenuItem())
        appMenu.addItem(.separator())
        appMenu.addItem(updateMenuItem())
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Schnaps", action: #selector(quit), key: "q"))
        let editMenu=NSMenu(title:"Edit")
        for (title,action,key) in [("Undo","undo:","z"),("Redo","redo:","Z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] {
            let entry=NSMenuItem(title:title,action:Selector(action),keyEquivalent:key.lowercased())
            entry.keyEquivalentModifierMask=key=="Z" ? [.command,.shift]:[.command]
            editMenu.addItem(entry)
        }
        editMenu.addItem(.separator())
        for (title,key,tag) in [("Find…","f",1),("Find Next","g",2),("Find Previous","G",3)] {
            let entry=NSMenuItem(title:title,action:Selector("performFindPanelAction:"),keyEquivalent:key.lowercased())
            entry.keyEquivalentModifierMask=key=="G" ? [.command,.shift]:[.command];entry.tag=tag
            editMenu.addItem(entry)
        }
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem=NSMenuItem();editItem.submenu=editMenu;mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func preferencesChanged() {
        // AppKit visibility/policy setters can post another defaults notification inline.
        guard !applyingPreferences, let statusItem else { return }
        applyingPreferences = true
        defer { applyingPreferences = false }
        updateDockVisibility()
        let showMenuBar = UserDefaults.standard.bool(forKey: PreferenceKey.showMenuBar)
        if statusItem.isVisible != showMenuBar { statusItem.isVisible = showMenuBar }
        NSApp.appearance = MeasurementPreferences.appearance
        let language = UserDefaults.standard.string(forKey: PreferenceKey.language) ?? "system"
        if language != menuLanguage {
            menuLanguage = language
            buildMenus()
            settingsWindow?.title = L("Schnaps Settings")
        }
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

    private func toolOverlayMenuItem() -> NSMenuItem {
        let entry = item("Tool Overlay", action: #selector(toggleToolOverlay), key: "")
        entry.state = toolOverlay.isEnabled ? .on : .off
        toolOverlayMenuItems.append(entry)
        return entry
    }
    private func updateToolOverlayMenu() {
        for item in toolOverlayMenuItems { item.state = toolOverlay.isEnabled ? .on : .off }
    }
    @objc private func toggleToolOverlay() { toolOverlay.toggle() }

    private func designToolsMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Design Tools", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for (index, tool) in DesignTool.allCases.enumerated() {
            let entry = item(tool.rawValue, action: #selector(launchDesignTool(_:)), key: ["r","g","b","o","s","l","x"][index], modifiers:[.command,.control])
            entry.tag = index; menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item("Image & Window Preview…", action:#selector(showImagePreview), key:""))
        menu.addItem(item("Responsive Web Preview…", action:#selector(showBrowserPreview), key:""))
        menu.addItem(item("Text Inspector…", action: #selector(showTextTools), key: ""))
        menu.addItem(item("Tool Inspector…", action: #selector(editDesignTools), key: ""))
        menu.addItem(item("Edit on Screen", action: #selector(editOnScreen), key: "e", modifiers:[.command,.control]))
        menu.addItem(item("Hide Design Tools", action: #selector(hideDesignTools), key: "h", modifiers:[.command,.control]))
        menu.addItem(item("Copy Sampled Color", action: #selector(copySampledColor), key: "c", modifiers:[.command,.control]))
        parent.submenu = menu; return parent
    }
    @objc private func launchDesignTool(_ sender: NSMenuItem) {
        guard DesignTool.allCases.indices.contains(sender.tag) else { return }
        activateDesignTool(DesignTool.allCases[sender.tag])
    }
    private func activateDesignTool(_ tool: DesignTool) {
        overlay.stop(); settingsWindow?.orderOut(nil)
        designTools.activate(tool)
    }
    @objc private func editDesignTools() { toolOverlay.inspect() }
    @objc private func showImagePreview() { overlay.stop(); ImagePreview.shared.show() }
    @objc private func showBrowserPreview() { overlay.stop(); BrowserPreview.shared.show() }
    @objc private func showTextTools() { overlay.stop(); textInspector.show() }
    @objc private func editOnScreen() {
        settingsWindow?.orderOut(nil);overlay.stop()
        if !DesignTools.shared.isActive { DesignTools.shared.visible=true };DesignTools.shared.editing.toggle()
    }
    @objc private func copySampledColor() { DesignTools.shared.copyColor() }
    @objc private func hideDesignTools() { DesignTools.shared.hide() }

    private func toleranceMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: L("Color Tolerance"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L("Color Tolerance"))
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
        let value = MeasurementPreferences.selectedTolerance.rawValue
        for entry in menu.items { entry.state = entry.tag == value ? .on : .off }
    }

    @objc private func selectTolerance(_ sender: NSMenuItem) {
        if let preset = TolerancePreset(rawValue: sender.tag) { MeasurementPreferences.selectTolerance(preset) }
    }

    private func updateMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Check for Updates…"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = updaterController
        return item
    }

    private func item(_ title: String, action: Selector, key: String, modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: L(title), action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    @objc func startDefaultTool() {
        start(mode: MeasurementMode(rawValue: UserDefaults.standard.string(forKey: PreferenceKey.defaultTool) ?? "") ?? .findDimensions)
    }

    @objc private func findDimensions() { start(mode: .findDimensions) }
    @objc private func measureArea() { start(mode: .area) }

    private func start(mode: MeasurementMode) {
        guard !recordingPermission.requesting else { return }
        designTools.state.hide()
        recordingPermission.refresh()
        if mode == .findDimensions && !recordingPermission.granted {
            showSettings()
            let alert = NSAlert()
            alert.messageText = L("Allow Screen Recording to Find Dimensions")
            alert.informativeText = L("Schnaps uses a still image of your screen to find edges. Allow access, or measure an area manually.")
            alert.addButton(withTitle: L(recordingPermission.hasRequested ? "Open Settings…" : "Allow Screen Recording…"))
            alert.addButton(withTitle: L("Measure Area"))
            alert.addButton(withTitle: L("Cancel"))
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if recordingPermission.hasRequested {
                    recordingPermission.openSettings()
                } else {
                    Task { [weak self] in
                        guard let self else { return }
                        await recordingPermission.request()
                        if recordingPermission.granted {
                            settingsWindow?.orderOut(nil)
                            overlay.toggle(mode: mode)
                        }
                    }
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
        DesignTools.shared.editing=false
        overlay.stop()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = L("Schnaps Settings")
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.minSize = NSSize(width: 720, height: 500)
            window.setFrameAutosaveName("SchnapSettings")
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(
                shortcutWarning: shortcutWarning,
                navigation: settingsNavigation, updates: UpdateSettings(updater: updaterController.updater, channels: updateChannels)))
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
                let delegate=Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
                switch id.id {
                case 1,2: delegate.start(mode:id.id==2 ? .findDimensions:.area)
                case 3...9:
                    delegate.overlay.stop();delegate.settingsWindow?.orderOut(nil)
                    delegate.designTools.activate(DesignTool.allCases[Int(id.id)-3])
                case 10: delegate.editOnScreen()
                case 11: delegate.hideDesignTools()
                case 12: delegate.copySampledColor()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, pointer, &handler)
        let shortcuts:[(UInt32,Int,UInt32)] = [
            (1,kVK_ANSI_M,UInt32(cmdKey|shiftKey)),(2,kVK_ANSI_F,UInt32(cmdKey|shiftKey)),
            (3,kVK_ANSI_R,UInt32(cmdKey|controlKey)),(4,kVK_ANSI_G,UInt32(cmdKey|controlKey)),
            (5,kVK_ANSI_B,UInt32(cmdKey|controlKey)),(6,kVK_ANSI_O,UInt32(cmdKey|controlKey)),
            (7,kVK_ANSI_S,UInt32(cmdKey|controlKey)),(8,kVK_ANSI_L,UInt32(cmdKey|controlKey)),
            (9,kVK_ANSI_X,UInt32(cmdKey|controlKey)),(10,kVK_ANSI_E,UInt32(cmdKey|controlKey)),
            (11,kVK_ANSI_H,UInt32(cmdKey|controlKey)),(12,kVK_ANSI_C,UInt32(cmdKey|controlKey))
        ]
        for (id,key,modifiers) in shortcuts {
            var hotKey: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(key), modifiers,
                                            EventHotKeyID(signature: 0x5343484E, id: id),
                                            GetApplicationEventTarget(), 0, &hotKey)
            if result == noErr, let hotKey { hotKeys.append(hotKey) }
            else { shortcutWarning = "A global shortcut is in use by another app. Use the Schnaps menu bar to activate the tool." }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        toolOverlay.prepareToTerminate()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
