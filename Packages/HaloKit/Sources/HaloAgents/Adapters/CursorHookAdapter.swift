import Foundation
import HaloCore
import HaloHookBridge

/// Cursor's hook protocol. Read-only: Cursor has no hook that fires only when approval is
/// needed, so Halo never gates its tool calls (see docs/spikes/agent-adapters.md).
public struct CursorHookAdapter: AgentAdapter {
    public let tool = AgentTool.cursor

    public init() {}

    public func event(from payload: Data) throws -> AgentEvent? {
        let hook = try JSONDecoder().decode(Payload.self, from: payload)
        guard let kind = kind(of: hook) else { return nil }
        return AgentEvent(
            sessionID: sessionID(hook.conversationID),
            tool: tool,
            kind: kind,
            workingDirectory: hook.workspaceRoots?.first,
            hookEventName: hook.hookEventName
        )
    }

    public func reply(to event: AgentEvent, decision: ApprovalDecision?) -> HookReply {
        // `beforeSubmitPrompt` gates the prompt, so say so explicitly rather than rely on defaults.
        guard event.hookEventName == "beforeSubmitPrompt" else { return .passThrough }
        return HookReply(output: Data(#"{"continue":true}"#.utf8))
    }

    private func kind(of hook: Payload) -> AgentEvent.Kind? {
        switch hook.hookEventName {
        case "beforeSubmitPrompt": hook.prompt.map(AgentEvent.Kind.promptSubmitted)
        case "stop": .waitingForReply(lastMessage: nil)
        case "sessionEnd": .sessionEnded
        default: nil
        }
    }
}

private extension CursorHookAdapter {
    struct Payload: Decodable {
        let conversationID: String
        let hookEventName: String
        let workspaceRoots: [String]?
        let prompt: String?

        enum CodingKeys: String, CodingKey {
            case conversationID = "conversation_id"
            case hookEventName = "hook_event_name"
            case workspaceRoots = "workspace_roots"
            case prompt
        }
    }
}
