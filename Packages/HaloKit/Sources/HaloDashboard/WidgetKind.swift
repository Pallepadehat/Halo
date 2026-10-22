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
        case .nowPlaying: "Music and Spotify on your Mac, without switching windows."
        case .brightness: "Your display's brightness, one swipe away."
        case .volume: "Your Mac's output volume."
        case .cpu: "How hard your Mac is working, and what's responsible."
        case .memory: "Memory in use, and the app holding the most."
        case .storage: "Space left on your startup disk."
        case .network: "Download and upload, right now."
        case .agents: "Claude Code, Codex and Cursor. Approve without switching."
        case .trackpad: "A large trackpad for your Mac."
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

    public var minimumSize: GridSize {
        switch self {
        case .clock: GridSize(width: 3, height: 2)
        case .nowPlaying: GridSize(width: 4, height: 1)
        case .brightness, .volume: GridSize(width: 1, height: 3)
        case .cpu, .memory, .storage, .network: GridSize(width: 3, height: 2)
        case .agents: GridSize(width: 4, height: 3)
        case .trackpad: GridSize(width: 3, height: 3)
        case .deck: GridSize(width: 3, height: 2)
        }
    }

    public var defaultSize: GridSize {
        switch self {
        case .clock: GridSize(width: 8, height: 3)
        case .nowPlaying: GridSize(width: 6, height: 1)
        case .brightness, .volume: GridSize(width: 1, height: 4)
        case .cpu, .memory, .storage, .network: GridSize(width: 5, height: 2)
        case .agents: GridSize(width: 7, height: 6)
        case .trackpad: GridSize(width: 4, height: 4)
        case .deck: GridSize(width: 4, height: 3)
        }
    }

    public var maximumSize: GridSize {
        switch self {
        case .brightness, .volume: GridSize(width: 2, height: Grid.rows)
        case .nowPlaying: GridSize(width: Grid.columns, height: 2)
        default: GridSize(width: Grid.columns, height: Grid.rows)
        }
    }

    public var sizeRange: ClosedRange<GridSize> {
        minimumSize...maximumSize
    }
}
