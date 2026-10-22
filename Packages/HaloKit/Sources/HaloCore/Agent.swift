import Foundation

/// An AI coding tool Halo can follow.
public enum AgentTool: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case cursor

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }

    /// Whether Halo can answer this tool's permission prompts.
    /// Cursor has no "approval needed" hook, so it ships read-only (see docs/spikes/agent-adapters.md).
    public var supportsApprovals: Bool {
        self != .cursor
    }
}

public enum AgentStatus: String, Codable, Sendable {
    /// Seen, but no turn in progress yet.
    case idle
    case running
    case waitingForApproval
    /// The agent finished its turn or asked a question.
    case waitingForReply
}

/// One agent conversation, as reported by the Mac helper.
public struct AgentSession: Codable, Sendable, Identifiable, Hashable {
    /// Unique across tools: `"<tool>:<native session id>"`.
    public typealias ID = String

    public let id: ID
    public let tool: AgentTool
    public var title: String
    /// Last path component of the working directory, e.g. `"Halo"`.
    public var project: String?
    public var status: AgentStatus
    public var latestMessage: String?
    public var pendingApprovals: [ApprovalRequest]
    public var updatedAt: Date

    public init(
        id: ID,
        tool: AgentTool,
        title: String,
        project: String? = nil,
        status: AgentStatus = .idle,
        latestMessage: String? = nil,
        pendingApprovals: [ApprovalRequest] = [],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.tool = tool
        self.title = title
        self.project = project
        self.status = status
        self.latestMessage = latestMessage
        self.pendingApprovals = pendingApprovals
        self.updatedAt = updatedAt
    }

    public static func id(tool: AgentTool, nativeID: String) -> ID {
        "\(tool.rawValue):\(nativeID)"
    }

    public var needsAttention: Bool {
        status == .waitingForApproval || status == .waitingForReply
    }
}

/// A tool call the agent wants to make and is waiting on a human for.
public struct ApprovalRequest: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let sessionID: AgentSession.ID
    /// The agent's name for the tool, e.g. `"Bash"` or `"Edit"`.
    public let toolName: String
    /// The one line worth reading from arm's length, e.g. the shell command.
    public let summary: String
    /// The agent's own explanation, when it gives one.
    public let detail: String?
    public let requestedAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: AgentSession.ID,
        toolName: String,
        summary: String,
        detail: String? = nil,
        requestedAt: Date = .now
    ) {
        self.id = id
        self.sessionID = sessionID
        self.toolName = toolName
        self.summary = summary
        self.detail = detail
        self.requestedAt = requestedAt
    }
}

public enum ApprovalDecision: Codable, Sendable, Hashable {
    case allow
    case deny(reason: String?)
}
