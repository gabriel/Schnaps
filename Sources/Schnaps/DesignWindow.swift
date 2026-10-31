import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import ScreenCaptureKit

struct DesignWindow: Identifiable {
  let id: UInt32
  let title: String
}
extension DesignTools {
  func refreshWindows() {
    ScreenRecordingPermission.shared.refresh()
    guard ScreenRecordingPermission.shared.granted else {
      error = "Allow Screen Recording in Settings → Permissions to follow another window."
      return
    }
    Task {
      do {
        let content = try await SCShareableContent.excludingDesktopWindows(
          true, onScreenWindowsOnly: true)
        let previews = PreviewWindowRole.sourceIDs
        availableWindows = content.windows.filter {
          ($0.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier
            || previews.contains($0.windowID))
            && $0.windowLayer == 0 && $0.frame.width > 20 && $0.frame.height > 20
        }.map {
          DesignWindow(
            id: $0.windowID,
            title: ($0.owningApplication?.applicationName ?? "Window") + " — "
              + ($0.title ?? "Untitled"))
        }.sorted { $0.title < $1.title }
      } catch { self.error = error.localizedDescription }
    }
  }
}

extension DesignTools {
  func resizeAttachedWindow(width: Double) {
    guard width.isFinite, width >= 240, width <= 16000, let selected,
      let id = selected.attachedWindow,
      let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
      let info = list.first(where: {
        ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
      }),
      let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
      let dictionary = info[kCGWindowBounds as String] as? [String: Any],
      let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
    else {
      error = "Choose an attached window first."
      return
    }
    guard
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    else {
      error =
        "Allow Schnaps in System Settings → Privacy & Security → Accessibility to resize another app’s window."
      NSWorkspace.shared.open(
        URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
      return
    }
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
      let windows = value as? [AXUIElement]
    else {
      error = "This application does not expose resizable windows."
      return
    }
    // Match public accessibility geometry to the selected ScreenCaptureKit window.
    let candidates = windows.filter { window in
      var position: CFTypeRef?
      var size: CFTypeRef?
      guard
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
          == .success,
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
        let position, let size, CFGetTypeID(position) == AXValueGetTypeID(),
        CFGetTypeID(size) == AXValueGetTypeID()
      else { return false }
      var p = CGPoint.zero
      var s = CGSize.zero
      guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &p),
        AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &s)
      else { return false }
      return abs(p.x - rect.minX) < 2 && abs(p.y - rect.minY) < 2 && abs(s.width - rect.width) < 2
        && abs(s.height - rect.height) < 2
    }
    guard candidates.count == 1 else {
      error =
        "The selected window could not be identified unambiguously. Use Responsive Preview instead."
      return
    }
    var size = CGSize(width: width, height: rect.height)
    guard let value = AXValueCreate(.cgSize, &size),
      AXUIElementSetAttributeValue(candidates[0], kAXSizeAttribute as CFString, value) == .success
    else {
      error = "This window cannot be resized to that width."
      return
    }
  }
}
