/// Everything that can live on a page.
public enum WidgetKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case clock
    case nowPlaying
    case brightness
    case volume
    case cpu
    case memory
    case storage
    case network
    case agents
    case trackpad
    case deck

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clock: "Clock"
        case .nowPlaying: "Now Playing"
        case .brightness: "Brightness"
        case .volume: "Volume"
        case .cpu: "Processor"
        case .memory: "Memory"
        case .storage: "Storage"
        case .network: "Network"
        case .agents: "Agents"
        case .trackpad: "Trackpad"
        case .deck: "Deck"
        }
    }

    public var summary: String {
        switch self {
        case .clock: "The time, the date and what's next on your calendar."
        case .nowPlaying: "Music on your Mac, without switching windows."
        case .brightness: "Every display's brightness, one swipe away."
        case .volume: "Your Mac's output volume."
        case .cpu: "How hard your Mac is working, and what's responsible."
        case .memory: "Memory in use, and the app holding the most."
        case .storage: "Space left on your startup disk."
        case .network: "Download and upload, right now."
        case .agents: "Claude Code, Codex and Cursor. Approve without switching."
        case .trackpad: "A large trackpad for your Mac, with gestures of your own."
        case .deck: "Your Shortcuts and everyday actions, one tap each."
        }
    }

    /// An SF Symbol for the gallery and edit mode.
    public var symbol: String {
        switch self {
        case .clock: "clock"
        case .nowPlaying: "music.note"
        case .brightness: "sun.max"
        case .volume: "speaker.wave.2"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .network: "network"
        case .agents: "sparkles"
        case .trackpad: "hand.point.up.left"
        case .deck: "square.grid.3x2"
        }
    }

    /// The sizes this widget is designed for, smallest first.
    public var families: [WidgetFamily] {
        switch self {
        case .clock: [.small, .medium, .large, .extraLarge]
        case .nowPlaying: [.small, .medium, .large]
        case .brightness, .volume: [.slim]
        case .cpu, .memory, .storage, .network: [.small, .medium, .large]
        case .agents: [.medium, .large, .extraLarge]
        case .trackpad: [.medium, .large, .extraLarge]
        case .deck: [.small, .medium, .large]
        }
    }

    public var defaultFamily: WidgetFamily {
        switch self {
        case .clock, .nowPlaying, .deck: .medium
        case .brightness, .volume: .slim
        case .cpu, .memory, .storage, .network: .small
        case .agents, .trackpad: .large
        }
    }

    /// Whether the widget has something to set up, shown as Edit Widget in edit mode.
    public var isConfigurable: Bool {
        self == .deck || self == .trackpad
    }
}
