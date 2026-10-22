/// The six v1 modes. Each mode solves one job (see docs/PRD.md).
public enum Mode: String, CaseIterable, Codable, Sendable, Identifiable {
    case zen
    case trackpad
    case pulse
    case agents
    case launch
    case deck

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .zen: "Zen"
        case .trackpad: "Trackpad"
        case .pulse: "Pulse"
        case .agents: "Agents"
        case .launch: "Launch"
        case .deck: "Deck"
        }
    }

    public var systemImage: String {
        switch self {
        case .zen: "moon.stars"
        case .trackpad: "hand.point.up.left"
        case .pulse: "waveform.path.ecg"
        case .agents: "sparkles"
        case .launch: "square.grid.2x2"
        case .deck: "rectangle.grid.3x2"
        }
    }
}
