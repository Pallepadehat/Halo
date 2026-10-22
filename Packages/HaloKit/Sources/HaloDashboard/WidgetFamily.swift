/// Widget sizes, after Apple's own: every widget comes in a few fixed shapes rather than any
/// rectangle, so pages stay orderly and each size can be designed on purpose.
public enum WidgetFamily: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    /// Halo's own: one tall control, such as a slider.
    case slim
    case small
    case medium
    case large
    case extraLarge

    public var id: String { rawValue }

    /// In cells of the 12 × 6 page grid.
    public var size: GridSize {
        switch self {
        case .slim: GridSize(width: 1, height: 3)
        case .small: GridSize(width: 3, height: 2)
        case .medium: GridSize(width: 6, height: 2)
        case .large: GridSize(width: 6, height: 4)
        case .extraLarge: GridSize(width: 12, height: 4)
        }
    }

    public var title: String {
        switch self {
        case .slim: "Slim"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
