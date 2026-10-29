import CoreGraphics
import Foundation

public enum ClipboardFormat: String, CaseIterable, Sendable {
    case widthHeight, heightWidth, cssWidthFirst, cssHeightFirst, sassWidthFirst, sassHeightFirst
    public var title: String {
        switch self {
        case .widthHeight: "Width, height"
        case .heightWidth: "Height, width"
        case .cssWidthFirst: "CSS (width first)"
        case .cssHeightFirst: "CSS (height first)"
        case .sassWidthFirst: "SASS (width first)"
        case .sassHeightFirst: "SASS (height first)"
        }
    }
}

public enum AspectRatioStyle: String, CaseIterable, Sendable {
    case automatic, standard, reduced, commonOnly
    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .standard: "Standard (16:9)"
        case .reduced: "Reduced (1.78:1)"
        case .commonOnly: "Only common values"
        }
    }
    public func label(width: CGFloat, height: CGFloat) -> String? {
        guard width.isFinite, height.isFinite, width > 0, height > 0,
            width < CGFloat(Int.max / 100), height < CGFloat(Int.max / 100)
        else { return nil }
        let ratio = width / height
        let common = [
            (1, 1), (4, 3), (3, 2), (16, 9), (16, 10), (2, 1), (3, 4), (2, 3), (9, 16), (10, 16), (1, 2), (21, 9),
        ]
        let match = common.min { abs(ratio - Double($0.0) / Double($0.1)) < abs(ratio - Double($1.0) / Double($1.1)) }
        if self == .commonOnly || self == .automatic,
            let (w, h) = match, abs(ratio / (Double(w) / Double(h)) - 1) <= 0.005
        {
            return "\(w):\(h)"
        }
        if self == .commonOnly { return nil }
        if self == .reduced { return "\(MeasurementPresentation.number(ratio, rounded: false)):1" }
        var w = max(1, Int((width * 100).rounded()))
        var h = max(1, Int((height * 100).rounded()))
        func gcd(_ x: Int, _ y: Int) -> Int {
            var a = x
            var b = y
            while b != 0 { (a, b) = (b, a % b) }
            return a
        }
        let divisor = gcd(w, h)
        w /= divisor
        h /= divisor
        if self == .automatic, max(w, h) > 100 { return "\(MeasurementPresentation.number(ratio, rounded: false)):1" }
        return "\(w):\(h)"
    }
}

public struct MeasurementPresentation: Sendable {
    public var unit: MeasurementUnit
    public var roundedPoints: Bool
    public var showUnits: Bool
    public var showIndicators: Bool
    public var clipboardFormat: ClipboardFormat
    public init(
        unit: MeasurementUnit = .points, roundedPoints: Bool = true, showUnits: Bool = true,
        showIndicators: Bool = false, clipboardFormat: ClipboardFormat = .widthHeight
    ) {
        self.unit = unit
        self.roundedPoints = roundedPoints
        self.showUnits = showUnits
        self.showIndicators = showIndicators
        self.clipboardFormat = clipboardFormat
    }
    public static func number(_ value: CGFloat, rounded: Bool) -> String {
        guard value.isFinite else { return "0" }
        if abs(value) < (rounded ? 0.5 : 0.005) { return "0" }
        let string = String(
            format: rounded ? "%.0f" : "%.2f", locale: Locale(identifier: "en_US_POSIX"),
            Double(rounded ? value.rounded() : value))
        guard !rounded else { return string }
        return string.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }
    public func value(_ points: CGFloat, scale: CGFloat) -> String {
        Self.number(points * (unit == .pixels ? scale : 1), rounded: unit == .pixels || roundedPoints)
    }
    public func distance(_ points: CGFloat, scale: CGFloat, horizontal: Bool? = nil) -> String {
        let indicator = showIndicators ? horizontal.map { $0 ? "W " : "H " } ?? "" : ""
        return indicator + value(points, scale: scale) + (showUnits ? " \(unit.rawValue)" : "")
    }
    public func label(_ rect: CGRect, scale: CGFloat) -> String {
        let w = value(rect.width, scale: scale)
        let h = value(rect.height, scale: scale)
        return (showIndicators ? "W \(w) × H \(h)" : "\(w) × \(h)") + (showUnits ? " \(unit.rawValue)" : "")
    }
    public func clipboard(_ rect: CGRect, scale: CGFloat, forceCSS: Bool = false) -> String {
        let format = forceCSS ? ClipboardFormat.cssWidthFirst : clipboardFormat
        if format == .widthHeight || format == .heightWidth {
            let suffix = showUnits ? " \(unit.rawValue)" : ""
            let values = [value(rect.width, scale: scale) + suffix, value(rect.height, scale: scale) + suffix]
            return (format == .heightWidth ? Array(values.reversed()) : values).joined(separator: ", ")
        }
        // CSS pixels use logical screen points, independent of Retina display scale.
        let w = Self.number(rect.width, rounded: roundedPoints)
        let h = Self.number(rect.height, rounded: roundedPoints)
        let heightFirst = format == .cssHeightFirst || format == .sassHeightFirst
        let entries = heightFirst ? [("height", h), ("width", w)] : [("width", w), ("height", h)]
        let sass = format == .sassWidthFirst || format == .sassHeightFirst
        return entries.map { "\($0.0): \($0.1)px" + (sass ? "" : ";") }.joined(separator: sass ? "\n" : " ")
    }
}

public enum MeasurementSnapping {
    public static func apply(
        _ dimensions: Dimensions, at point: CGPoint,
        verticalGuides: [CGFloat] = [], horizontalGuides: [CGFloat] = [],
        rectangles: [CGRect] = []
    ) -> Dimensions {
        var xs = verticalGuides
        var ys = horizontalGuides
        for rect in rectangles where !rect.isNull && !rect.isEmpty {
            if point.y >= rect.minY && point.y <= rect.maxY { xs += [rect.minX, rect.maxX] }
            if point.x >= rect.minX && point.x <= rect.maxX { ys += [rect.minY, rect.maxY] }
        }
        func snapped(_ span: DimensionSpan, candidates: [CGFloat], position: CGFloat) -> DimensionSpan {
            let horizontal = span.isHorizontal
            let lower = horizontal ? span.start.x : span.start.y
            let upper = horizontal ? span.end.x : span.end.y
            let valid = candidates.filter { $0.isFinite && $0 >= lower && $0 <= upper }
            let a = valid.filter { $0 < position }.max() ?? lower
            let b = valid.filter { $0 > position }.min() ?? upper
            return horizontal
                ? DimensionSpan(start: CGPoint(x: a, y: span.start.y), end: CGPoint(x: b, y: span.end.y))
                : DimensionSpan(start: CGPoint(x: span.start.x, y: a), end: CGPoint(x: span.end.x, y: b))
        }
        return Dimensions(
            horizontal: snapped(dimensions.horizontal, candidates: xs, position: point.x),
            vertical: snapped(dimensions.vertical, candidates: ys, position: point.y))
    }
}

public enum ScreenshotGeometry {
    public static func region(_ rect: CGRect, in bounds: CGRect, padding: Int, togglePadding: Bool) -> CGRect {
        let effective = togglePadding ? (padding == 0 ? 101 : 0) : padding
        let amount = effective > 100 ? max(8, min(64, min(rect.width, rect.height) * 0.08)) : CGFloat(max(0, effective))
        return rect.insetBy(dx: -amount, dy: -amount).intersection(bounds)
    }
    public static func pixelRect(_ rect: CGRect, scaleX: CGFloat, scaleY: CGFloat, imageSize: CGSize) -> CGRect {
        guard scaleX.isFinite, scaleY.isFinite, scaleX > 0, scaleY > 0,
            !rect.isNull, !rect.isEmpty, rect.minX.isFinite, rect.minY.isFinite,
            rect.maxX.isFinite, rect.maxY.isFinite
        else { return .null }
        return CGRect(
            x: floor(rect.minX * scaleX), y: floor(rect.minY * scaleY),
            width: ceil(rect.maxX * scaleX) - floor(rect.minX * scaleX),
            height: ceil(rect.maxY * scaleY) - floor(rect.minY * scaleY)
        )
        .intersection(CGRect(origin: .zero, size: imageSize))
    }
}
