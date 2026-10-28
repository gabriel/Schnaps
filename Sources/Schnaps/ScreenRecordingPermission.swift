import AppKit
import Combine
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenRecordingPermission: ObservableObject {
    static let shared = ScreenRecordingPermission()
    private static let requestedKey = "screenRecordingPermissionRequested"
    @Published private(set) var granted = CGPreflightScreenCaptureAccess()
    @Published private(set) var requesting = false
    @Published private(set) var hasRequested = UserDefaults.standard.bool(forKey: requestedKey)

    var buttonTitle: String {
        granted || hasRequested ? "Open Screen Recording Settings…" : "Allow Screen Recording…"
    }

    func refresh() { granted = CGPreflightScreenCaptureAccess() }

    func request() async {
        guard !requesting else { return }
        requesting = true
        hasRequested = true
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        defer { requesting = false }
        do {
            // ScreenCaptureKit triggers the system consent prompt. The legacy
            // CGRequestScreenCaptureAccess can return false without registering the app.
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            granted = true
        } catch {
            refresh()
        }
        // Declining consent leaves the user in the app. Settings opens only on request.
    }

    func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
