import Foundation
import HaloCore

public let haloProtocolVersion = 1

/// Mac helper → iPad.
public enum MacMessage: Codable, Sendable, Equatable {
    case hello(macName: String, protocolVersion: Int)
    case metrics(SystemMetrics)
    case agents([AgentSession])
}

/// iPad → Mac helper.
public enum PadMessage: Codable, Sendable, Equatable {
    case hello(deviceName: String, protocolVersion: Int)
    case pointer(PointerEvent)
    case resolveApproval(id: ApprovalRequest.ID, decision: ApprovalDecision)
    case agentAction(sessionID: AgentSession.ID, action: AgentAction)
    case runAction(id: String)
}

public enum PointerEvent: Codable, Sendable, Equatable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case click(button: MouseButton)
    case gesture(String)
}

public enum MouseButton: String, Codable, Sendable {
    case left, right
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
