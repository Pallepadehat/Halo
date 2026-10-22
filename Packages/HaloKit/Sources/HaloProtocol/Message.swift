import Foundation
import HaloCore

/// Bump on any wire change: devices refuse peers that speak a different version.
public let haloProtocolVersion = 2

/// Mac helper → iPad.
public enum MacMessage: Codable, Sendable, Equatable {
    case hello(macName: String, protocolVersion: Int)
    case metrics(SystemMetrics)
    /// Sent on connect so Pulse's sparklines start full.
    case metricsHistory([SystemMetrics])
    case agents([AgentSession])
    /// Whether the helper may move the pointer (it needs Accessibility permission).
    case trackpadAvailability(isAvailable: Bool)
    /// Answers `PadMessage.ping` immediately, on the same path pointer events take.
    case pong(id: UInt32)
}

/// iPad → Mac helper.
public enum PadMessage: Codable, Sendable, Equatable {
    case hello(deviceID: UUID, deviceName: String, protocolVersion: Int)
    case pointer(PointerEvent)
    case ping(id: UInt32)
    case resolveApproval(id: ApprovalRequest.ID, decision: ApprovalDecision)
    case agentAction(sessionID: AgentSession.ID, action: AgentAction)
    case runAction(id: String)
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
