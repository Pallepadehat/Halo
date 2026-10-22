import Foundation
import HaloCore
import HaloHookBridge

/// Translates one agent tool's hook protocol to and from `AgentEvent`.
public protocol AgentAdapter: Sendable {
    var tool: AgentTool { get }

    /// The normalised event for a raw hook payload, or `nil` for hooks Halo doesn't care about.
    func event(from payload: Data) throws -> AgentEvent?

    /// What the hook should print. A `nil` decision means "no opinion": the agent carries on as usual.
    func reply(to event: AgentEvent, decision: ApprovalDecision?) -> HookReply
}

extension AgentAdapter {
    func sessionID(_ nativeID: String) -> AgentSession.ID {
        AgentSession.id(tool: tool, nativeID: nativeID)
    }
}

public extension Array where Element == any AgentAdapter {
    static var all: [any AgentAdapter] {
        [ClaudeStyleHookAdapter.claudeCode, ClaudeStyleHookAdapter.codex, CursorHookAdapter()]
    }
}
