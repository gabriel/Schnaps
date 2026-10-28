import AppKit
import MeasurementCore

@MainActor
final class OverlayController: NSObject {
    private var windows: [OverlayWindow] = []
    private var generation = UUID()
    private var preparing = false
    private var previousApp: NSRunningApplication?
    private var saved: [CGDirectDisplayID: [CGRect]] = [:]
    private var savedDistances: [CGDirectDisplayID: [DimensionSpan]] = [:]
    private var mode: MeasurementMode = .area
    var isActive: Bool { preparing || !windows.isEmpty }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func preferencesChanged() {
        for window in windows { (window.contentView as? MeasurementView)?.synchronizeTolerance() }
    }

    func toggle(mode: MeasurementMode = .area) {
        if preparing || !windows.isEmpty {
            let sameMode = self.mode == mode
            stop()
            if sameMode { return }
        }
        self.mode = mode
        preparing = true
        previousApp = NSWorkspace.shared.frontmostApplication
        let token = UUID()
        generation = token
        Task {
            var snapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]
            var captureFailed = false
            if CGPreflightScreenCaptureAccess() {
                do { snapshots = try await ScreenSnapshot.capture() }
                catch { captureFailed = true; NSLog("Schnaps capture: %@", error.localizedDescription) }
            }
            guard generation == token else { return }
            preparing = false
            for screen in NSScreen.screens {
                let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
                let window = OverlayWindow(screen: screen)
                let view = MeasurementView(frame: CGRect(origin: .zero, size: screen.frame.size),
                                           scale: screen.backingScaleFactor, snapshot: snapshots[id], mode: mode)
                view.pinned = (saved[id] ?? []).map { $0.intersection(view.bounds) }.filter { !$0.isNull && !$0.isEmpty }
                view.pinnedDistances = savedDistances[id] ?? []
                view.onModeChanged = { [weak self] mode in self?.mode = mode }
                view.onClose = { [weak self] in self?.stop() }
                view.onRefresh = { [weak self, weak view] in
                    guard let view else { return }
                    self?.refresh(mode: view.mode)
                }
                window.contentView = view
                window.makeFirstResponder(view)
                window.orderFrontRegardless()
                windows.append(window)
            }
            NSApp.activate(ignoringOtherApps: true)
            let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
            target?.makeKeyAndOrderFront(nil)
            for window in windows {
                guard let view = window.contentView as? MeasurementView else { continue }
                view.initializePointer()
                if captureFailed && mode == .findDimensions { view.reportCaptureFailure() }
            }
        }
    }

    func stop() {
        generation = UUID()
        preparing = false
        for window in windows {
            if let id = (window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
               let view = window.contentView as? MeasurementView {
                saved[id] = view.pinned
                savedDistances[id] = view.pinnedDistances
            }
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        if let previousApp, previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate(options: [])
        }
        previousApp = nil
    }

    private func refresh(mode: MeasurementMode) {
        let activeMode = mode
        stop()
        toggle(mode: activeMode)
    }
}

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Animating a full-display screenshot looks like the desktop itself zooms.
        animationBehavior = .none
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
    var pinnedDistances: [DimensionSpan] = [] { didSet { needsDisplay = true } }
    var onClose: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onModeChanged: ((MeasurementMode) -> Void)?
    private let scale: CGFloat
    private let snapshot: ScreenSnapshot?
    private var selection: CGRect?
    private var detectionRegion: CGRect?
    private var scrollRemainder: CGFloat = 0
    private var liveDimensions: Dimensions?
    private var heldDimensions: Dimensions?
    private var manualDrag = false
    private var cursor = CGPoint.zero
    private var anchor = CGPoint.zero
    private var original: CGRect?
    private var dragging = false
    private enum DragMode { case create, move, resize(CGPoint) }
    private var dragMode = DragMode.create
    private var unit: MeasurementUnit = .points
    private(set) var mode: MeasurementMode
    private var tolerance = 18
    private var tracking: NSTrackingArea?
    private var message: String?
    private var messageTimer: Timer?
    private let accent = NSColor.controlAccentColor
    private var showAlignment = false
    private var guides: [(vertical: Bool, position: CGFloat)] = []

    init(frame: CGRect, scale: CGFloat, snapshot: ScreenSnapshot?, mode: MeasurementMode) {
        self.scale = scale
        self.snapshot = snapshot
        self.mode = mode
        self.unit = MeasurementUnit(rawValue: UserDefaults.standard.string(forKey: PreferenceKey.unit) ?? "pt") ?? .points
        self.tolerance = TolerancePreset.closest(to: UserDefaults.standard.integer(forKey: PreferenceKey.tolerance)).rawValue
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("measurement-overlay")
        setAccessibilityLabel("Measurement canvas")
        setAccessibilityHelp("Drag to measure. S switches tools, U switches units, T changes tolerance, Enter copies, Escape exits.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

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
    override func mouseExited(with event: NSEvent) { liveDimensions = nil; needsDisplay = true }
    override func mouseMoved(with event: NSEvent) {
        cursor = convert(event.locationInWindow, from: nil)
        updateLiveDimensions()
        needsDisplay = true
    }

    func initializePointer() {
        guard let window, window.frame.contains(NSEvent.mouseLocation) else { return }
        cursor = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        updateLiveDimensions()
        needsDisplay = true
    }

    private func updateLiveDimensions() {
        if selection == nil, heldDimensions == nil, mode == .findDimensions {
            liveDimensions = snapshot?.dimensions(at: cursor, tolerance: tolerance)
        } else { liveDimensions = nil }
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
        manualDrag = event.type == .rightMouseDown
        original = selection
        detectionRegion = nil
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
        heldDimensions = nil
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
        liveDimensions = nil
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if case .create = dragMode {
            if !dragging {
                heldDimensions = mode == .findDimensions ? snapshot?.dimensions(at: anchor, tolerance: tolerance) : nil
                liveDimensions = nil
            } else if mode == .findDimensions, !manualDrag, event.modifierFlags.intersection([.option, .shift]).isEmpty,
                      let rect = selection, let detected = snapshot?.objectBounds(in: rect, tolerance: tolerance) {
                detectionRegion = rect
                selection = detected
            }
        }
        if let rect = selection, rect.width < 1 / scale || rect.height < 1 / scale { selection = nil }
        dragging = false
        needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        anchor = rounded(convert(event.locationInWindow, from: nil))
        cursor = anchor
        dragging = false
        manualDrag = true
        detectionRegion = nil
        original = nil
        dragMode = .create
        selection = nil
        heldDimensions = nil
        liveDimensions = nil
    }
    override func rightMouseDragged(with event: NSEvent) { mouseDragged(with: event) }
    override func rightMouseUp(with event: NSEvent) {
        if dragging { mouseUp(with: event) }
        else { selection = nil; heldDimensions = nil; mouseMoved(with: event) }
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
            if selection != nil { selection = nil; detectionRegion = nil }
            else if heldDimensions != nil { heldDimensions = nil }
            else if !pinnedDistances.isEmpty { pinnedDistances.removeLast() }
            else if !pinned.isEmpty { pinned.removeLast() }
            updateLiveDimensions()
        case 123, 124, 125, 126:
            guard let rect = selection else { return }
            detectionRegion = nil
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
            case "s": toggleMode()
            case "r": refresh()
            case "t": cycleTolerance(backward: shift)
            case "c" where command: copyDimensions(css: shift)
            case "k" where command: clear()
            case "z" where command:
                if !pinned.isEmpty { selection = pinned.removeLast(); detectionRegion = nil }
            case "h":
                if shift { guides.append((false, cursor.y)) }
                else { pinDistance(horizontal: true) }
            case "v":
                if shift { guides.append((true, cursor.x)) }
                else { pinDistance(horizontal: false) }
            default: break
            }
        }
        needsDisplay = true
    }

    private func toggleUnit() {
        unit = unit == .points ? .pixels : .points
        UserDefaults.standard.set(unit.rawValue, forKey: PreferenceKey.unit)
        flash(unit == .points ? "Screen points" : "Display pixels")
    }
    private func toggleMode() {
        detectionRegion = nil
        scrollRemainder = 0
        mode = mode == .area ? .findDimensions : .area
        onModeChanged?(mode)
        liveDimensions = nil
        heldDimensions = nil
        updateLiveDimensions()
        if mode == .findDimensions && snapshot == nil { reportCaptureFailure() }
        else { flash(mode.rawValue) }
    }

    func reportCaptureFailure() {
        flash("Capture unavailable. R to retry, S to measure an area.")
    }

    private func cycleTolerance(backward: Bool) {
        let preset = TolerancePreset.closest(to: tolerance).cycled(backward: backward)
        setTolerance(preset.rawValue)
        flash("Tolerance: \(preset.title)")
    }

    private func setTolerance(_ value: Int) {
        let value = TolerancePreset.closest(to: value).rawValue
        UserDefaults.standard.set(value, forKey: PreferenceKey.tolerance)
        synchronizeTolerance()
    }

    func synchronizeTolerance() {
        let value = TolerancePreset.closest(to: UserDefaults.standard.integer(forKey: PreferenceKey.tolerance)).rawValue
        guard value != tolerance else { return }
        tolerance = value
        if mode == .findDimensions {
            if heldDimensions != nil { heldDimensions = snapshot?.dimensions(at: anchor, tolerance: tolerance) }
            if let detectionRegion { selection = snapshot?.objectBounds(in: detectionRegion, tolerance: tolerance) ?? detectionRegion }
        }
        updateLiveDimensions()
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard mode == .findDimensions, snapshot != nil, !dragging,
              UserDefaults.standard.bool(forKey: PreferenceKey.scrollTolerance),
              event.momentumPhase.isEmpty else { return }
        let delta = event.scrollingDeltaY
        guard abs(delta) > abs(event.scrollingDeltaX), delta != 0 else { return }
        if event.phase == .began { scrollRemainder = 0 }
        // Trackpads send many tiny events; a mouse wheel advances once per notch.
        scrollRemainder += event.hasPreciseScrollingDeltas ? delta / 10 : delta
        let steps = Int(scrollRemainder)
        guard steps != 0 else { return }
        scrollRemainder -= CGFloat(steps)
        let preset = TolerancePreset.closest(to: tolerance).stepped(by: steps)
        setTolerance(preset.rawValue)
        flash("Tolerance: \(preset.title)")
    }

    private func pin() {
        if let rect = selection, rect.width > 0, rect.height > 0 {
            pinned.append(rect)
            detectionRegion = nil
            selection = nil
        } else if let dimensions = heldDimensions ?? liveDimensions {
            pinnedDistances.append(contentsOf: [dimensions.horizontal, dimensions.vertical])
            heldDimensions = nil
        } else { return }
        updateLiveDimensions()
        flash("Measurement pinned")
    }
    private func pinDistance(horizontal: Bool) {
        guard let dimensions = heldDimensions ?? liveDimensions else { return }
        pinnedDistances.append(horizontal ? dimensions.horizontal : dimensions.vertical)
        flash(horizontal ? "Horizontal distance pinned" : "Vertical distance pinned")
    }
    private func clear() {
        pinned.removeAll(); pinnedDistances.removeAll(); guides.removeAll()
        detectionRegion = nil
        selection = nil; heldDimensions = nil
        updateLiveDimensions()
        flash("Measurements cleared")
    }
    private func refresh() { onRefresh?() }

    private func copyDimensions(css: Bool) {
        guard let rect = selection ?? (heldDimensions ?? liveDimensions)?.rect ?? pinned.last else {
            if let distance = pinnedDistances.last {
                let factor = unit == .pixels ? scale : 1
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(Int((distance.length * factor).rounded())) \(unit.rawValue)", forType: .string)
                flash("Distance copied")
            } else { flash("Move the pointer or drag a region first") }
            return
        }
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
        let description = (selection ?? (heldDimensions ?? liveDimensions)?.rect).map { MeasurementGeometry.label($0, scale: scale, unit: unit) }
        setAccessibilityValue(description ?? "No active measurement")
        if let snapshot {
            NSImage(cgImage: snapshot.image, size: bounds.size).draw(in: bounds, from: .zero,
                operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
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
        if let rect = selection { drawMeasurement(rect, index: nil, active: true, labels: &labels) }
        for distance in pinnedDistances { drawDistance(distance, held: true, labels: &labels) }
        if let dimensions = heldDimensions ?? liveDimensions {
            drawDistance(dimensions.horizontal, held: heldDimensions != nil, labels: &labels)
            drawDistance(dimensions.vertical, held: heldDimensions != nil, labels: &labels)
        }
        if let message {
            _ = pill(message, at: CGPoint(x: bounds.midX, y: bounds.height - 46), centered: true, color: .white)
        }
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
        if position.y > bounds.height - 40 { position.y = max(8, rect.minY - 34) }
        var label = labelRect(text, at: position, centered: true)
        for _ in 0..<20 {
            if labels.contains(where: { $0.insetBy(dx: -3, dy: -3).intersects(label) }) {
                position.y += 30
                if position.y > bounds.height - 36 { position.y = 8; position.x += 40 }
                label = labelRect(text, at: position, centered: true)
            } else { break }
        }
        line(from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: label.midX, y: label.minY),
             color: color.withAlphaComponent(0.65), dashed: true)
        labels.append(pill(text, at: position, centered: true, color: color))
    }
    private func drawDistance(_ distance: DimensionSpan, held: Bool, labels: inout [CGRect]) {
        let color = held ? NSColor.secondaryLabelColor : accent
        line(from: distance.start, to: distance.end, color: color, dashed: held)
        let horizontal = distance.isHorizontal
        for point in [distance.start, distance.end] {
            let dx: CGFloat = horizontal ? 0 : 5
            let dy: CGFloat = horizontal ? 5 : 0
            line(from: CGPoint(x: point.x - dx, y: point.y - dy),
                 to: CGPoint(x: point.x + dx, y: point.y + dy), color: color, dashed: false)
        }
        let factor = unit == .pixels ? scale : 1
        let text = "\(Int((distance.length * factor).rounded())) \(unit.rawValue)"
        var position = horizontal
            ? CGPoint(x: (distance.start.x + distance.end.x) / 2, y: distance.start.y + 10)
            : CGPoint(x: distance.start.x + 44, y: (distance.start.y + distance.end.y) / 2)
        for _ in 0..<12 {
            let rect = labelRect(text, at: position, centered: true)
            if labels.contains(where: { $0.intersects(rect) }) { position.y += 30 }
            else { break }
        }
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
        [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize), .foregroundColor: NSColor.labelColor]
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
        NSColor.windowBackgroundColor.setFill()
        rect.fill()
        var attributes = textAttributes
        attributes[.foregroundColor] = NSColor.labelColor
        (text as NSString).draw(in: rect.insetBy(dx: 11, dy: 6), withAttributes: attributes)
        return rect
    }
}
