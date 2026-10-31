import AppKit
import Combine

enum MenuBarIconState: CaseIterable {
    case idle, findDimensions, measureArea, marksVisible

    static func resolve(measurement: MeasurementMode?, designToolsActive: Bool) -> Self {
        switch measurement {
        case .findDimensions: .findDimensions
        case .area: .measureArea
        case nil: designToolsActive ? .marksVisible : .idle
        }
    }
    var title: String {
        switch self {
        case .idle: "Ready"
        case .findDimensions: "Find Dimensions"
        case .measureArea: "Measure Area"
        case .marksVisible: "Design Tools Visible"
        }
    }
}

/// Consume the publishers' new values instead of reading @Published properties
/// during willSet. Geometry, color samples, and editing focus don't change the glyph.
@MainActor
final class MenuBarStatus: ObservableObject {
    @Published private(set) var state: MenuBarIconState = .idle
    private var measurement: MeasurementMode?
    private var designToolsActive = false
    private var subscription: AnyCancellable?

    init(designTools: DesignTools) {
        subscription = designTools.$markers
            .combineLatest(designTools.$visible, designTools.$loupe, designTools.$crosshair)
            .map { markers, visible, loupe, crosshair in
                (visible && markers.contains(where: \.isVisible)) || loupe || crosshair
            }
            .removeDuplicates()
            .sink { [weak self] active in
                self?.designToolsActive = active
                self?.refresh()
            }
    }
    func measurementChanged(_ mode: MeasurementMode?) {
        measurement = mode
        refresh()
    }
    private func refresh() {
        let next = MenuBarIconState.resolve(measurement: measurement, designToolsActive: designToolsActive)
        if state != next { state = next }
    }
}

/// Original Split Caliper paths from the approved study, drawn at the display's
/// resolution. Template tinting supplies light, dark, and selected appearances.
@MainActor
enum MenuBarIcon {
    private static let images = Dictionary(uniqueKeysWithValues: MenuBarIconState.allCases.map { ($0, draw($0)) })
    static func image(for state: MenuBarIconState) -> NSImage { images[state]! }

    private static func draw(_ state: MenuBarIconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            NSColor.black.setStroke()
            func stroke(_ points: [NSPoint], width: CGFloat = 1.6) {
                let path = NSBezierPath()
                path.lineWidth = width
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: points[0])
                for point in points.dropFirst() { path.line(to: point) }
                path.stroke()
            }
            stroke([NSPoint(x: 4.5, y: 9), NSPoint(x: 4.5, y: 17), NSPoint(x: 12.5, y: 17)])
            stroke([NSPoint(x: 9.5, y: 5), NSPoint(x: 17.5, y: 5), NSPoint(x: 17.5, y: 13)])
            switch state {
            case .idle: break
            case .findDimensions:
                stroke([NSPoint(x: 5.5, y: 11), NSPoint(x: 16.5, y: 11)], width: 1.35)
                stroke([NSPoint(x: 11, y: 9), NSPoint(x: 11, y: 13)], width: 1.25)
            case .measureArea:
                let path = NSBezierPath(roundedRect: NSRect(x: 8, y: 8, width: 6, height: 6), xRadius: 0.55, yRadius: 0.55)
                path.lineWidth = 1.25
                path.stroke()
            case .marksVisible:
                stroke([NSPoint(x: 8, y: 8), NSPoint(x: 14, y: 8)], width: 1.25)
                stroke([NSPoint(x: 14, y: 8), NSPoint(x: 14, y: 14)], width: 1.25)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Schnaps — \(state.title)"
        return image
    }
}
