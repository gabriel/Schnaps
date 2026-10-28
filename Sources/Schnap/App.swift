import AppKit
import SwiftUI
import Carbon

@main
struct SchnapApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var welcome: NSWindow?
    private let overlay = OverlayController()
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Schnap measurements")
        let menu = NSMenu()
        menu.addItem(item("Start Measuring", action: #selector(start), key: "m"))
        menu.addItem(item("Schnap…", action: #selector(showWelcome), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Schnap", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        installHotKey()
        showWelcome()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWelcome()
        return true
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc func start() {
        welcome?.orderOut(nil)
        overlay.toggle()
    }

    @objc private func screensChanged() { overlay.stop() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showWelcome() {
        if welcome == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Schnap"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: WelcomeView(start: { [weak self] in self?.start() }))
            window.center()
            welcome = window
        }
        NSApp.activate(ignoringOtherApps: true)
        welcome?.makeKeyAndOrderFront(nil)
    }

    private func installHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().start()
            }
            return noErr
        }, 1, &eventType, pointer, &handler)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(cmdKey | shiftKey),
                                        EventHotKeyID(signature: 0x5343484E, id: 1),
                                        GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { NSLog("Schnap: ⇧⌘M is unavailable; use the menu bar to measure.") }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct WelcomeView: View {
    var start: () -> Void
    @State private var granted = CGPreflightScreenCaptureAccess()
    @State private var requested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "ruler").font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.mint).frame(width: 60, height: 60)
                    .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Text("MADE TO MEASURE").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("A little more precise.").font(.system(size: 34, weight: .semibold))
                Text("Measure anything on your screen.\nNative to your Mac. Built entirely in Swift.")
                    .font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(4)
            }
            VStack(spacing: 13) {
                instruction("cursorarrow.motionlines", "Drag to measure", "Shift for a square. Drag inside to move; corners to resize.")
                instruction("scope", "Find the edges", "Hover for a color-based measurement. Click to hold it.")
                instruction("pin", "Keep the details", "Space pins. Arrows nudge. Enter copies. Esc closes.")
            }
            Divider()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: granted ? "checkmark.shield" : "rectangle.dashed.badge.record")
                    .foregroundStyle(granted ? .mint : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(granted ? "Edge detection is ready" : "Enable edge detection").font(.system(size: 13, weight: .medium))
                    Text("Screen Recording access lets Schnap find edges in a still image. Captures stay in memory on your Mac.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !granted {
                        Button(requested ? "Open Screen Recording Settings" : "Allow Screen Recording…") {
                            requested = true
                            if !CGRequestScreenCaptureAccess() {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                            }
                            granted = CGPreflightScreenCaptureAccess()
                        }.buttonStyle(.link).font(.system(size: 12))
                    }
                }
            }
            HStack {
                Button(action: start) {
                    HStack { Text("Start measuring"); Spacer(); Text("⇧⌘M").opacity(0.65) }
                        .font(.system(size: 14, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 7)
                }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
            }
        }
        .padding(32).frame(width: 540).background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = CGPreflightScreenCaptureAccess()
        }
    }

    private func instruction(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.mint).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
