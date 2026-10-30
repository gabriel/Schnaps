import AppKit
import MeasurementCore

@MainActor
enum MeasurementPreferences {
    static let defaults: [String: Any] = [
        PreferenceKey.unit: "pt", PreferenceKey.roundPoints: true, PreferenceKey.tolerance: 18,
        PreferenceKey.scrollTolerance: true, PreferenceKey.showInDock: false, PreferenceKey.showMenuBar: true,
        PreferenceKey.defaultTool: MeasurementMode.findDimensions.rawValue,
        PreferenceKey.language: "system", PreferenceKey.clipboardFormat: ClipboardFormat.widthHeight.rawValue,
        PreferenceKey.showUnits: true, PreferenceKey.showIndicators: false, PreferenceKey.showCursor: true,
        PreferenceKey.aspectStyle: AspectRatioStyle.commonOnly.rawValue, PreferenceKey.aspectDistance: false,
        PreferenceKey.aspectArea: true, PreferenceKey.snapGuides: true, PreferenceKey.snapObjects: true,
        PreferenceKey.freezeScreen: true, PreferenceKey.screenshotFormat: "png", PreferenceKey.screenshotScale: false,
        PreferenceKey.screenshotSound: true, PreferenceKey.screenshotPadding: 0,
        PreferenceKey.screenshotFolder: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            .path,
        PreferenceKey.appearance: "system", PreferenceKey.animations: true,
        PreferenceKey.overlayColor: "FF375FFF", PreferenceKey.alternativeColor: "252525FF",
        PreferenceKey.guideColor: "0A84FFFF", PreferenceKey.autoContrast: true,
        PreferenceKey.toleranceZero: 0, PreferenceKey.toleranceLow: 8,
        PreferenceKey.toleranceMedium: 18, PreferenceKey.toleranceHigh: 36,
    ]
    static var presentation: MeasurementPresentation {
        let d = UserDefaults.standard
        return MeasurementPresentation(
            unit: MeasurementUnit(rawValue: d.string(forKey: PreferenceKey.unit) ?? "pt") ?? .points,
            roundedPoints: d.bool(forKey: PreferenceKey.roundPoints),
            showUnits: d.bool(forKey: PreferenceKey.showUnits),
            showIndicators: d.bool(forKey: PreferenceKey.showIndicators),
            clipboardFormat: ClipboardFormat(rawValue: d.string(forKey: PreferenceKey.clipboardFormat) ?? "")
                ?? .widthHeight)
    }
    static func toleranceKey(_ preset: TolerancePreset) -> String {
        switch preset {
        case .zero: PreferenceKey.toleranceZero
        case .low: PreferenceKey.toleranceLow
        case .medium: PreferenceKey.toleranceMedium
        case .high: PreferenceKey.toleranceHigh
        }
    }
    static var selectedTolerance: TolerancePreset { selectedTolerance(in: .standard) }
    static func selectedTolerance(in d: UserDefaults) -> TolerancePreset {
        if d.object(forKey: PreferenceKey.selectedTolerance) != nil,
            let value = TolerancePreset(rawValue: d.integer(forKey: PreferenceKey.selectedTolerance))
        {
            return value
        }
        return TolerancePreset.closest(to: d.integer(forKey: PreferenceKey.tolerance))
    }
    static func threshold(_ preset: TolerancePreset, in d: UserDefaults = .standard) -> Int {
        let key = toleranceKey(preset)
        return min(100, max(0, d.object(forKey: key) == nil ? preset.rawValue : d.integer(forKey: key)))
    }
    static var tolerance: Int { threshold(selectedTolerance) }
    static func selectTolerance(_ preset: TolerancePreset, in d: UserDefaults = .standard) {
        d.set(preset.rawValue, forKey: PreferenceKey.selectedTolerance)
        d.set(threshold(preset, in: d), forKey: PreferenceKey.tolerance)
    }
    static func resetTolerance() {
        for preset in TolerancePreset.allCases {
            UserDefaults.standard.set(preset.rawValue, forKey: toleranceKey(preset))
        }
        selectTolerance(.medium)
    }
    static func resetAppearance() {
        for key in [
            PreferenceKey.appearance, PreferenceKey.animations, PreferenceKey.overlayColor,
            PreferenceKey.alternativeColor, PreferenceKey.guideColor, PreferenceKey.autoContrast,
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    static var appearance: NSAppearance? {
        switch UserDefaults.standard.string(forKey: PreferenceKey.appearance) {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
    static func color(_ key: String) -> NSColor {
        NSColor(schnapsHex: UserDefaults.standard.string(forKey: key) ?? defaults[key] as? String ?? "FF375FFF")
            ?? .controlAccentColor
    }
}

extension NSColor {
    convenience init?(schnapsHex: String) {
        guard schnapsHex.count == 8, let value = UInt32(schnapsHex, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 24) & 255) / 255, green: CGFloat((value >> 16) & 255) / 255,
            blue: CGFloat((value >> 8) & 255) / 255, alpha: CGFloat(value & 255) / 255)
    }
    var schnapsHex: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "FF375FFF" }
        let parts = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent].map {
            Int((min(1, max(0, $0)) * 255).rounded())
        }
        return parts.map { String(format: "%02X", $0) }.joined()
    }
    var relativeLuminance: CGFloat {
        guard let rgb = usingColorSpace(.sRGB) else { return 0.5 }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722
            * linear(rgb.blueComponent)
    }
}
