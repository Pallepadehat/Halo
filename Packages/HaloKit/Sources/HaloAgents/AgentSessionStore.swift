import Foundation
import HaloCore

/// Folds `AgentEvent`s into the current set of agent sessions. A value type with no I/O,
/// so every state transition is a plain unit test.
public struct AgentSessionStore: Sendable, Equatable {
    public static let maximumTitleLength = 60

    private var sessionsByID: [AgentSession.ID: AgentSession] = [:]
    /// Sessions whose title came from a prompt, so later prompts don't rename them.
    private var titledFromPrompt: Set<AgentSession.ID> = []

    public init() {}

    /// Sessions that need you first, then most recently active.
    public var sessions: [AgentSession] {
        sessionsByID.values.sorted { lhs, rhs in
            if lhs.needsAttention != rhs.needsAttention { return lhs.needsAttention }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public subscript(id: AgentSession.ID) -> AgentSession? {
        sessionsByID[id]
    }

    public mutating func apply(_ event: AgentEvent) {
        if case .sessionEnded = event.kind {
            sessionsByID[event.sessionID] = nil
            titledFromPrompt.remove(event.sessionID)
            return
        }

        var session = sessionsByID[event.sessionID] ?? Self.newSession(for: event)
        session.updatedAt = event.date

        switch event.kind {
        case .sessionStarted, .sessionEnded:
            break
        case .promptSubmitted(let prompt):
            if titledFromPrompt.insert(session.id).inserted {
                session.title = Self.title(from: prompt) ?? session.title
            }
            session.status = .running
        case .approvalRequested(let request):
            session.pendingApprovals.append(request)
            session.status = .waitingForApproval
        case .toolCompleted:
            if session.pendingApprovals.isEmpty { session.status = .running }
        case .waitingForReply(let lastMessage):
            session.latestMessage = lastMessage ?? session.latestMessage
            session.pendingApprovals.removeAll()
            session.status = .waitingForReply
        }

        sessionsByID[session.id] = session
    }

    /// Drops an approval Halo can no longer answer.
    ///
    /// If it was answered here, the agent resumes. If it expired, the agent is now showing its
    /// own prompt on the Mac, so the session keeps waiting until the next tool event.
    public mutating func removeApproval(_ id: ApprovalRequest.ID, in sessionID: AgentSession.ID, wasAnswered: Bool) {
        guard var session = sessionsByID[sessionID] else { return }
        session.pendingApprovals.removeAll { $0.id == id }
        if wasAnswered, session.pendingApprovals.isEmpty, session.status == .waitingForApproval {
            session.status = .running
        }
        sessionsByID[sessionID] = session
    }

    private static func newSession(for event: AgentEvent) -> AgentSession {
        let project = event.workingDirectory.map { URL(filePath: $0).lastPathComponent }
        return AgentSession(
            id: event.sessionID,
            tool: event.tool,
            title: project ?? event.tool.displayName,
            project: project,
            updatedAt: event.date
        )
    }

    /// The prompt's first line, trimmed to fit a glanceable row.
    private static func title(from prompt: String) -> String? {
        let firstLine = prompt
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespaces)
        guard let firstLine, !firstLine.isEmpty else { return nil }
        guard firstLine.count > maximumTitleLength else { return firstLine }
        return firstLine.prefix(maximumTitleLength - 1) + "…"
    }
}
