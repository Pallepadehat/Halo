import Foundation
import HaloCore

/// A hook call, normalised across tools. Adapters produce these; `AgentSessionStore` consumes them.
public struct AgentEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case sessionStarted
        case promptSubmitted(String)
        case approvalRequested(ApprovalRequest)
        case toolCompleted
        /// The turn ended or the agent is idle at its prompt. `nil` keeps the previous message.
        case waitingForReply(lastMessage: String?)
        case sessionEnded
    }

    public let sessionID: AgentSession.ID
    public let tool: AgentTool
    public let kind: Kind
    public let workingDirectory: String?
    /// The tool's own event name (e.g. `"PermissionRequest"`), kept so the adapter can shape its reply.
    public let hookEventName: String
    public let date: Date

    public init(
        sessionID: AgentSession.ID,
        tool: AgentTool,
        kind: Kind,
        workingDirectory: String? = nil,
        hookEventName: String,
        date: Date = .now
    ) {
        self.sessionID = sessionID
        self.tool = tool
        self.kind = kind
        self.workingDirectory = workingDirectory
        self.hookEventName = hookEventName
        self.date = date
    }
}
