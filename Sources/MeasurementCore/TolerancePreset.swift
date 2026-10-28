/// Shared values for menus, settings, keyboard cycling, and scroll adjustment.
public enum TolerancePreset: Int, CaseIterable, Sendable {
    case zero = 0
    case low = 8
    case medium = 18
    case high = 36

    public var title: String {
        switch self {
        case .zero: "Zero"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    public static func closest(to value: Int) -> Self {
        let bounded = min(high.rawValue, max(zero.rawValue, value))
        return allCases.min { abs($0.rawValue - bounded) < abs($1.rawValue - bounded) } ?? .medium
    }

    public func stepped(by amount: Int) -> Self {
        let index = Self.allCases.firstIndex(of: self)!
        let offset = min(Self.allCases.count, max(-Self.allCases.count, amount))
        return Self.allCases[min(Self.allCases.count - 1, max(0, index + offset))]
    }

    public func cycled(backward: Bool = false) -> Self {
        let index = Self.allCases.firstIndex(of: self)!
        return Self.allCases[(index + (backward ? Self.allCases.count - 1 : 1)) % Self.allCases.count]
    }
}
