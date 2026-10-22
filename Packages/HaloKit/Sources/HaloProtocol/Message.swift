import Foundation
import HaloCore

/// Bump on any wire change: devices refuse peers that speak a different version.
public let haloProtocolVersion = 5

/// Mac helper → iPad.
public enum MacMessage: Codable, Sendable, Equatable {
    case hello(macName: String, protocolVersion: Int)
    case metrics(SystemMetrics)
    /// Sent on connect so sparklines start full.
    case metricsHistory([SystemMetrics])
    case agents([AgentSession])
    /// Whether the helper may move the pointer (it needs Accessibility permission).
    case trackpadAvailability(isAvailable: Bool)
    /// Answers `PadMessage.ping` immediately, on the same path pointer events take.
    case pong(id: UInt32)

    /// The Mac's desktop picture, downscaled. The iPad blurs it into its backdrop.
    case wallpaper(jpeg: Data)
    /// The apps in the Mac's Dock. Icons follow separately, one message each.
    case launcher([LaunchItem])
    case appIcon(id: LaunchItem.ID, png: Data)
    case nowPlaying(NowPlaying?)
    /// Sent once per track.
    case artwork(trackID: String, jpeg: Data)
    case controls(SystemControls)
    case deck([DeckAction])
    case upNext(UpcomingEvent?)
}

/// iPad → Mac helper.
public enum PadMessage: Codable, Sendable, Equatable {
    case hello(deviceID: UUID, deviceName: String, protocolVersion: Int)
    case pointer(PointerEvent)
    case ping(id: UInt32)
    case resolveApproval(id: ApprovalRequest.ID, decision: ApprovalDecision)
    case agentAction(sessionID: AgentSession.ID, action: AgentAction)
    case launch(id: LaunchItem.ID)
    case media(MediaCommand)
    case setVolume(Double)
    case toggleMute
    case setBrightness(Double)
    case runAction(id: DeckAction.ID)
}

public enum AgentAction: Codable, Sendable, Equatable {
    case reply(String)
    case bringForward
}

public enum MessageCoder {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
