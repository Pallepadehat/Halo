import Foundation

public enum AgentTool: String, Codable, Sendable, CaseIterable {
    case claudeCode
    case codex
    case cursor
}

public enum AgentStatus: String, Codable, Sendable {
    case running
    case waitingForApproval
    case waitingForReply
    case idle
    case finished
}

/// One agent conversation as reported by a Mac-side adapter.
public struct AgentSession: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var tool: AgentTool
    public var title: String
    public var status: AgentStatus
    /// Human-readable description of the pending tool request, if any.
    public var pendingRequest: String?
    /// False when the adapter can only read state (see PRD risk: ship read-only if approval isn't safe).
    public var canApprove: Bool
    public var updatedAt: Date

    public init(
        id: String,
        tool: AgentTool,
        title: String,
        status: AgentStatus,
        pendingRequest: String? = nil,
        canApprove: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.tool = tool
        self.title = title
        self.status = status
        self.pendingRequest = pendingRequest
        self.canApprove = canApprove
        self.updatedAt = updatedAt
    }

    public var needsAttention: Bool {
        status == .waitingForApproval || status == .waitingForReply
    }
}
