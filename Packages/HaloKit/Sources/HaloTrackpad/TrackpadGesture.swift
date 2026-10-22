/// Gestures a person can give their own meaning, such as running a Shortcut.
public enum TrackpadGesture: String, Codable, Sendable, CaseIterable, Identifiable {
    case threeFingerTap
    case fourFingerTap

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .threeFingerTap: "Three-Finger Tap"
        case .fourFingerTap: "Four-Finger Tap"
        }
    }

    public var symbol: String {
        switch self {
        case .threeFingerTap: "hand.tap"
        case .fourFingerTap: "hand.raised.fingers.spread"
        }
    }
}
