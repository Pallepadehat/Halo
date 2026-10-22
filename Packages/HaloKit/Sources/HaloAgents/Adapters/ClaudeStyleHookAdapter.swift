import Foundation
import HaloCore
import HaloHookBridge

/// Claude Code's hook protocol, which Codex adopted almost verbatim: same event names,
/// same snake_case payloads, same `PermissionRequest` decision shape.
public struct ClaudeStyleHookAdapter: AgentAdapter {
    public static let claudeCode = ClaudeStyleHookAdapter(tool: .claudeCode)
    public static let codex = ClaudeStyleHookAdapter(tool: .codex)

    public let tool: AgentTool

    private init(tool: AgentTool) {
        self.tool = tool
    }

    public func event(from payload: Data) throws -> AgentEvent? {
        let hook = try JSONDecoder().decode(Payload.self, from: payload)
        guard let kind = kind(of: hook) else { return nil }
        return AgentEvent(
            sessionID: sessionID(hook.sessionID),
            tool: tool,
            kind: kind,
            workingDirectory: hook.cwd,
            hookEventName: hook.hookEventName
        )
    }

    public func reply(to event: AgentEvent, decision: ApprovalDecision?) -> HookReply {
        guard event.hookEventName == "PermissionRequest", let decision else { return .passThrough }
        let output = PermissionRequestOutput(decision: decision)
        return HookReply(output: (try? JSONEncoder().encode(output)) ?? Data())
    }

    private func kind(of hook: Payload) -> AgentEvent.Kind? {
        switch hook.hookEventName {
        case "SessionStart":
            return .sessionStarted
        case "UserPromptSubmit":
            return hook.prompt.map(AgentEvent.Kind.promptSubmitted)
        case "PermissionRequest":
            guard let toolName = hook.toolName else { return nil }
            let call = ToolCallSummary(toolName: toolName, input: hook.toolInput)
            return .approvalRequested(ApprovalRequest(
                sessionID: sessionID(hook.sessionID),
                toolName: toolName,
                summary: call.summary,
                detail: call.detail
            ))
        case "PostToolUse":
            return .toolCompleted
        case "Notification" where hook.notificationType.map(Self.waitingNotifications.contains) == true:
            return .waitingForReply(lastMessage: nil)
        case "Stop":
            return .waitingForReply(lastMessage: hook.lastAssistantMessage)
        case "SessionEnd":
            return .sessionEnded
        default:
            return nil
        }
    }

    /// Claude Code notifications that mean "the agent is waiting on you". Permission prompts
    /// are excluded: `PermissionRequest` already covers them, with more detail.
    private static let waitingNotifications: Set<String> = ["idle_prompt", "agent_needs_input"]
}

private extension ClaudeStyleHookAdapter {
    struct Payload: Decodable {
        let sessionID: String
        let hookEventName: String
        let cwd: String?
        let prompt: String?
        let toolName: String?
        let toolInput: JSONValue?
        let notificationType: String?
        let lastAssistantMessage: String?

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case hookEventName = "hook_event_name"
            case cwd
            case prompt
            case toolName = "tool_name"
            case toolInput = "tool_input"
            case notificationType = "notification_type"
            case lastAssistantMessage = "last_assistant_message"
        }
    }

    /// `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`
    struct PermissionRequestOutput: Encodable {
        struct HookSpecificOutput: Encodable {
            let hookEventName = "PermissionRequest"
            let decision: Decision
        }

        struct Decision: Encodable {
            let behavior: String
            let message: String?
        }

        let hookSpecificOutput: HookSpecificOutput

        init(decision: ApprovalDecision) {
            let body = switch decision {
            case .allow: Decision(behavior: "allow", message: nil)
            case .deny(let reason): Decision(behavior: "deny", message: reason ?? "Denied from Halo.")
            }
            hookSpecificOutput = HookSpecificOutput(decision: body)
        }
    }
}
