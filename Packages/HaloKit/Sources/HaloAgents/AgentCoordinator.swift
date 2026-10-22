import Foundation
import HaloCore
import HaloHookBridge

/// The Mac helper's brain for agents: turns hook invocations into session state, and holds
/// permission requests open until someone answers them from Halo or the window runs out.
public actor AgentCoordinator {
    /// Every change to the session list, newest first. Single consumer.
    public nonisolated let sessionUpdates: AsyncStream<[AgentSession]>

    public static let defaultApprovalWindow: Duration = .seconds(90)

    /// How long a permission request waits for an answer from Halo before the agent falls
    /// back to its own prompt. `nil` never waits. Must stay below `HookConfiguration.approvalTimeout`.
    public var approvalWindow: Duration?

    private let adapters: [AgentTool: any AgentAdapter]
    private let updatesContinuation: AsyncStream<[AgentSession]>.Continuation
    private var store = AgentSessionStore()
    private var pendingDecisions: [ApprovalRequest.ID: CheckedContinuation<ApprovalDecision?, Never>] = [:]
    /// The agent process behind each session, from its latest hook call.
    private var hostProcesses: [AgentSession.ID: Int32] = [:]

    public init(adapters: [any AgentAdapter] = .all, approvalWindow: Duration? = defaultApprovalWindow) {
        self.adapters = Dictionary(adapters.map { ($0.tool, $0) }, uniquingKeysWith: { _, last in last })
        self.approvalWindow = approvalWindow
        (sessionUpdates, updatesContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public var sessions: [AgentSession] {
        store.sessions
    }

    public func setApprovalWindow(_ window: Duration?) {
        approvalWindow = window
    }

    /// Handles one hook call end to end. Suspends for as long as a permission request is open.
    public func handle(_ invocation: HookInvocation) async -> HookReply {
        guard let adapter = adapters[invocation.tool],
              let event = try? adapter.event(from: invocation.payload)
        else { return .passThrough }

        apply(event)
        if case .sessionEnded = event.kind {
            hostProcesses[event.sessionID] = nil
        } else if let process = invocation.parentProcess {
            hostProcesses[event.sessionID] = process
        }

        guard case .approvalRequested(let request) = event.kind else {
            return adapter.reply(to: event, decision: nil)
        }
        let decision = await decision(for: request)
        store.removeApproval(request.id, in: request.sessionID, wasAnswered: decision != nil)
        publish()
        return adapter.reply(to: event, decision: decision)
    }

    /// The agent process behind a session, to bring its window forward.
    public func hostProcess(for session: AgentSession.ID) -> Int32? {
        hostProcesses[session]
    }

    /// Answers an open permission request. Late answers (after the window closed) are ignored.
    public func resolve(_ id: ApprovalRequest.ID, with decision: ApprovalDecision) {
        pendingDecisions.removeValue(forKey: id)?.resume(returning: decision)
    }

    private func apply(_ event: AgentEvent) {
        store.apply(event)
        publish()
    }

    private func publish() {
        updatesContinuation.yield(store.sessions)
    }

    private func decision(for request: ApprovalRequest) async -> ApprovalDecision? {
        guard let approvalWindow else { return nil }

        let deadline = Task {
            try await Task.sleep(for: approvalWindow)
            expire(request.id)
        }
        defer { deadline.cancel() }

        return await withCheckedContinuation { pendingDecisions[request.id] = $0 }
    }

    private func expire(_ id: ApprovalRequest.ID) {
        pendingDecisions.removeValue(forKey: id)?.resume(returning: nil)
    }
}
