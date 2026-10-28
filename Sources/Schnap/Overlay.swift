import AppKit
import MeasurementCore

@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var generation = UUID()
    private var preparing = false
    private var previousApp: NSRunningApplication?
    private var saved: [CGDirectDisplayID: [CGRect]] = [:]

    func toggle() {
        if preparing || !windows.isEmpty { stop(); return }
        preparing = true
        previousApp = NSWorkspace.shared.frontmostApplication
        let token = UUID()
        generation = token
        Task {
            var snapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]
            var captureFailed = false
            if CGPreflightScreenCaptureAccess() {
                do { snapshots = try await ScreenSnapshot.capture() }
                catch { captureFailed = true; NSLog("Schnap capture: %@", error.localizedDescription) }
            }
            guard generation == token else { return }
            preparing = false
            for screen in NSScreen.screens {
                let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
                let window = OverlayWindow(screen: screen)
                let view = MeasurementView(frame: CGRect(origin: .zero, size: screen.frame.size),
                                           scale: screen.backingScaleFactor, snapshot: snapshots[id])
                view.pinned = saved[id] ?? []
                view.captureFailed = captureFailed
                view.onClose = { [weak self] in self?.stop() }
                view.onRefresh = { [weak self] in self?.refresh() }
                window.contentView = view
                window.makeFirstResponder(view)
                window.orderFrontRegardless()
                windows.append(window)
            }
            NSApp.activate(ignoringOtherApps: true)
            let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
            target?.makeKeyAndOrderFront(nil)
        }
    }

    func stop() {
        generation = UUID()
        preparing = false
        for window in windows {
            if let id = (window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
               let view = window.contentView as? MeasurementView { saved[id] = view.pinned }
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        if let previousApp, previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate(options: [])
        }
        previousApp = nil
    }

    private func refresh() {
        stop()
        toggle()
    }
}

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        acceptsMouseMovedEvents = true
        isRestorable = false
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class MeasurementView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var pinned: [CGRect] = [] { didSet { needsDisplay = true } }
    var captureFailed = false
    var onClose: (() -> Void)?
    var onRefresh: (() -> Void)?
    private let scale: CGFloat
    private let snapshot: ScreenSnapshot?
    private var selection: CGRect?
    private var hover: CGRect?
    private var cursor = CGPoint.zero
    private var anchor = CGPoint.zero
    private var original: CGRect?
    private var dragging = false
    private enum DragMode { case create, move, resize(CGPoint) }
    private var dragMode = DragMode.create
    private var unit: MeasurementUnit = .points
    private var edgeDetection = true
    private var tolerance = 18
    private var tracking: NSTrackingArea?
    private var message: String?
    private var messageTimer: Timer?
    private let toolbar = NSVisualEffectView()
    private var unitButton: NSButton!
    private var snapButton: NSButton!
    private var toleranceControl: NSSegmentedControl!
    private let accent = NSColor.systemMint
    private var showAlignment = false
    private var guides: [(vertical: Bool, position: CGFloat)] = []

    init(frame: CGRect, scale: CGFloat, snapshot: ScreenSnapshot?) {
        self.scale = scale
        self.snapshot = snapshot
        super.init(frame: frame)
        setAccessibilityIdentifier("measurement-overlay")
        setAccessibilityLabel("Measurement canvas. Drag to measure; Enter copies dimensions; Escape exits.")
        setupToolbar()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .recessed
        button.font = .systemFont(ofSize: 12, weight: .medium)
        return button
    }

    private func setupToolbar() {
        toolbar.material = .hudWindow
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 14
        toolbar.appearance = NSAppearance(named: .darkAqua)
        let title = NSTextField(labelWithString: "SCHNAP")
        title.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        title.textColor = accent
        unitButton = button("Points ▾", #selector(toggleUnit))
        unitButton.toolTip = "Switch between logical screen points and physical display pixels (U)"
        snapButton = button(snapshot == nil ? "Edges unavailable" : "Edges on", #selector(toggleSnap))
        snapButton.isEnabled = snapshot != nil
        snapButton.toolTip = "Toggle color-based edge detection (S). Requires Screen Recording access."
        toleranceControl = NSSegmentedControl(labels: ["8", "18", "36"], trackingMode: .selectOne,
                                               target: self, action: #selector(changeTolerance))
        toleranceControl.selectedSegment = 1
        toleranceControl.toolTip = "Color tolerance: low, medium, high"
        toleranceControl.isEnabled = snapshot != nil
        let stack = NSStackView(views: [title, unitButton, snapButton, toleranceControl,
                                       button("Pin ␣", #selector(pin)), button("Clear", #selector(clear)),
                                       button("Refresh", #selector(refresh)), button("Done  esc", #selector(done))])
        stack.spacing = 10
        stack.orientation = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)
        addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.centerXAnchor.constraint(equalTo: centerXAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 44),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -10)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func mouseEntered(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        mouseMoved(with: event)
    }
    override func mouseExited(with event: NSEvent) { hover = nil; needsDisplay = true }
    override func mouseMoved(with event: NSEvent) {
        cursor = convert(event.locationInWindow, from: nil)
        if !toolbar.frame.contains(cursor), selection == nil, edgeDetection {
            hover = snapshot?.edges(at: cursor, tolerance: tolerance, bounds: bounds)
        } else { hover = nil }
        needsDisplay = true
    }

    private func rounded(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (min(max(point.x, 0), bounds.width) * scale).rounded() / scale,
                y: (min(max(point.y, 0), bounds.height) * scale).rounded() / scale)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        anchor = rounded(convert(event.locationInWindow, from: nil))
        cursor = anchor
        dragging = false
        original = selection
        if let selection {
            let corners = [CGPoint(x: selection.minX, y: selection.minY), CGPoint(x: selection.maxX, y: selection.minY),
                           CGPoint(x: selection.minX, y: selection.maxY), CGPoint(x: selection.maxX, y: selection.maxY)]
            if let corner = corners.first(where: { hypot($0.x - anchor.x, $0.y - anchor.y) < 9 }) {
                let opposite = CGPoint(x: corner.x == selection.minX ? selection.maxX : selection.minX,
                                       y: corner.y == selection.minY ? selection.maxY : selection.minY)
                dragMode = .resize(opposite)
                return
            }
            if selection.contains(anchor) { dragMode = .move; return }
        }
        // Clicking a pin restores it for editing.
        if let index = pinned.lastIndex(where: { $0.contains(anchor) }) {
            selection = pinned.remove(at: index)
            original = selection
            dragMode = .move
            needsDisplay = true
            return
        }
        dragMode = .create
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = rounded(convert(event.locationInWindow, from: nil))
        guard dragging || hypot(point.x - anchor.x, point.y - anchor.y) >= 2 else { return }
        dragging = true
        cursor = point
        switch dragMode {
        case .create:
            selection = MeasurementGeometry.rectangle(from: anchor, to: point, within: bounds,
                                                       square: event.modifierFlags.contains(.shift))
        case .resize(let opposite):
            selection = MeasurementGeometry.rectangle(from: opposite, to: point, within: bounds,
                                                       square: event.modifierFlags.contains(.shift))
        case .move:
            if let original {
                selection = MeasurementGeometry.translated(original, dx: point.x - anchor.x, dy: point.y - anchor.y, within: bounds)
            }
        }
        hover = nil
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if !dragging, case .create = dragMode {
            selection = edgeDetection ? snapshot?.edges(at: anchor, tolerance: tolerance, bounds: bounds) : nil
        }
        if let rect = selection, rect.width < 1 / scale || rect.height < 1 / scale { selection = nil }
        dragging = false
        needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) {
        selection = nil
        mouseMoved(with: event)
    }
    override func flagsChanged(with event: NSEvent) {
        showAlignment = event.modifierFlags.contains(.shift)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 53: onClose?()
        case 36, 76: copyDimensions(css: shift)
        case 49: pin()
        case 51, 117:
            if selection != nil { selection = nil }
            else if !pinned.isEmpty { pinned.removeLast() }
        case 123, 124, 125, 126:
            guard let rect = selection else { return }
            let step: CGFloat = (shift ? 10 : 1) / (unit == .pixels ? scale : 1)
            let dx: CGFloat = event.keyCode == 123 ? -step : event.keyCode == 124 ? step : 0
            let dy: CGFloat = event.keyCode == 126 ? -step : event.keyCode == 125 ? step : 0
            if event.modifierFlags.contains(.option) {
                selection = CGRect(x: rect.minX, y: rect.minY,
                                   width: min(max(1 / scale, rect.width + dx), bounds.maxX - rect.minX),
                                   height: min(max(1 / scale, rect.height + dy), bounds.maxY - rect.minY))
            } else { selection = MeasurementGeometry.translated(rect, dx: dx, dy: dy, within: bounds) }
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "u": toggleUnit()
            case "s": toggleSnap()
            case "r": refresh()
            case "c" where command: copyDimensions(css: shift)
            case "k" where command: clear()
            case "z" where command:
                if !pinned.isEmpty { selection = pinned.removeLast() }
            case "h": guides.append((false, cursor.y))
            case "v": guides.append((true, cursor.x))
            default: break
            }
        }
        needsDisplay = true
    }

    @objc private func toggleUnit() {
        unit = unit == .points ? .pixels : .points
        unitButton.title = unit == .points ? "Points ▾" : "Pixels ▾"
        needsDisplay = true
    }
    @objc private func toggleSnap() {
        guard snapshot != nil else { return }
        edgeDetection.toggle()
        snapButton.title = edgeDetection ? "Edges on" : "Edges off"
        hover = nil
        needsDisplay = true
    }
    @objc private func changeTolerance() {
        tolerance = [8, 18, 36][max(0, toleranceControl.selectedSegment)]
        hover = nil
        needsDisplay = true
    }
    @objc private func pin() {
        guard let rect = selection ?? hover, rect.width > 0, rect.height > 0 else { return }
        pinned.append(rect)
        selection = nil
        hover = nil
        flash("Measurement pinned")
    }
    @objc private func clear() {
        pinned.removeAll(); guides.removeAll(); selection = nil; hover = nil
        flash("Canvas cleared")
    }
    @objc private func done() { onClose?() }
    @objc private func refresh() { onRefresh?() }

    private func copyDimensions(css: Bool) {
        guard let rect = selection ?? hover ?? pinned.last else { flash("Drag a region first"); return }
        let factor = unit == .pixels ? scale : 1
        let width = Int((rect.width * factor).rounded()), height = Int((rect.height * factor).rounded())
        // CSS uses logical pixels, corresponding to macOS screen points, regardless of display scale.
        let value = css ? "width: \(Int(rect.width.rounded()))px; height: \(Int(rect.height.rounded()))px;" : "\(width) × \(height) \(unit.rawValue)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        flash("Copied  \(value)")
    }
    private func flash(_ text: String) {
        messageTimer?.invalidate()
        message = text
        needsDisplay = true
        messageTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.message = nil; self?.needsDisplay = true }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let description = (selection ?? hover).map { MeasurementGeometry.label($0, scale: scale, unit: unit) }
        setAccessibilityValue(description ?? "No active measurement")
        if let snapshot {
            NSImage(cgImage: snapshot.image, size: bounds.size).draw(in: bounds, from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        NSColor.black.withAlphaComponent(snapshot == nil ? 0.025 : 0.12).setFill()
        bounds.fill()
        for guide in guides {
            line(from: guide.vertical ? CGPoint(x: guide.position, y: 0) : CGPoint(x: 0, y: guide.position),
                 to: guide.vertical ? CGPoint(x: guide.position, y: bounds.height) : CGPoint(x: bounds.width, y: guide.position),
                 color: .systemOrange, dashed: true)
        }
        if showAlignment {
            line(from: CGPoint(x: cursor.x, y: 0), to: CGPoint(x: cursor.x, y: bounds.height), color: accent.withAlphaComponent(0.6), dashed: true)
            line(from: CGPoint(x: 0, y: cursor.y), to: CGPoint(x: bounds.width, y: cursor.y), color: accent.withAlphaComponent(0.6), dashed: true)
        }
        var labels: [CGRect] = []
        for (index, rect) in pinned.enumerated() { drawMeasurement(rect, index: index + 1, active: false, labels: &labels) }
        if let rect = selection ?? hover { drawMeasurement(rect, index: nil, active: selection != nil, labels: &labels) }
        let status = message ?? (snapshot == nil
            ? (captureFailed ? "Capture failed · Manual measurement ready · Enable permission and Refresh to retry" : "Manual mode · Allow Screen Recording in Schnap to detect edges")
            : "Drag to measure   ·   Space pin   ·   Enter copy   ·   U units   ·   H / V guide   ·   Esc done")
        _ = pill(status, at: CGPoint(x: bounds.midX, y: bounds.height - 46), centered: true, color: .white)
    }

    private func drawMeasurement(_ rect: CGRect, index: Int?, active: Bool, labels: inout [CGRect]) {
        let color = index == nil ? accent : NSColor.systemOrange
        color.withAlphaComponent(active ? 0.09 : 0.045).setFill()
        rect.fill()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1 / scale
        if index != nil { path.setLineDash([4, 3], count: 2, phase: 0) }
        color.setStroke()
        path.stroke()
        if active {
            for point in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                          CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)] {
                NSColor.black.setFill()
                let handle = NSBezierPath(roundedRect: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6), xRadius: 1, yRadius: 1)
                handle.fill(); color.setStroke(); handle.stroke()
            }
        }
        let text = (index.map { "\($0)  ·  " } ?? "") + MeasurementGeometry.label(rect, scale: scale, unit: unit)
        var position = CGPoint(x: rect.midX, y: rect.maxY + 10)
        if position.y > bounds.height - 85 { position.y = max(100, rect.minY - 34) }
        var label = labelRect(text, at: position, centered: true)
        for _ in 0..<20 {
            if labels.contains(where: { $0.insetBy(dx: -3, dy: -3).intersects(label) }) || label.intersects(toolbar.frame) {
                position.y += 30
                if position.y > bounds.height - 80 { position.y = 100; position.x += 40 }
                label = labelRect(text, at: position, centered: true)
            } else { break }
        }
        line(from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: label.midX, y: label.minY),
             color: color.withAlphaComponent(0.65), dashed: true)
        labels.append(pill(text, at: position, centered: true, color: color))
    }
    private func line(from start: CGPoint, to end: CGPoint, color: NSColor, dashed: Bool) {
        let path = NSBezierPath()
        path.move(to: start); path.line(to: end)
        path.lineWidth = 1 / scale
        if dashed { path.setLineDash([3, 3], count: 2, phase: 0) }
        color.setStroke(); path.stroke()
    }
    private var textAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white]
    }
    private func labelRect(_ text: String, at point: CGPoint, centered: Bool) -> CGRect {
        let size = (text as NSString).size(withAttributes: textAttributes)
        let width = min(size.width + 22, bounds.width - 16)
        return CGRect(x: min(max(8, point.x - (centered ? width / 2 : 0)), bounds.width - width - 8),
                      y: min(max(8, point.y), bounds.height - 36), width: width, height: 28)
    }
    @discardableResult
    private func pill(_ text: String, at point: CGPoint, centered: Bool, color: NSColor) -> CGRect {
        let rect = labelRect(text, at: point, centered: centered)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedWhite: 0.09, alpha: 0.96).setFill(); path.fill()
        color.withAlphaComponent(0.4).setStroke(); path.lineWidth = 0.5; path.stroke()
        var attributes = textAttributes
        attributes[.foregroundColor] = color
        (text as NSString).draw(in: rect.insetBy(dx: 11, dy: 6), withAttributes: attributes)
        return rect
    }
}
