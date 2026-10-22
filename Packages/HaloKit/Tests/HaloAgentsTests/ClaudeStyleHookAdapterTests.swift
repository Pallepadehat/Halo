import Foundation
import Testing
import HaloCore
@testable import HaloAgents

@Suite struct ClaudeStyleHookAdapterTests {
    let adapter = ClaudeStyleHookAdapter.claudeCode

    @Test func permissionRequestBecomesApprovalRequest() throws {
        let event = try #require(try adapter.event(from: Fixture.claudePermissionRequest))
        guard case .approvalRequested(let request) = event.kind else {
            Issue.record("Expected an approval request, got \(event.kind)")
            return
        }
        #expect(event.sessionID == "claude-code:abc123")
        #expect(event.workingDirectory == "/Users/me/Halo")
        #expect(request.sessionID == event.sessionID)
        #expect(request.toolName == "Bash")
        #expect(request.summary == "rm -rf node_modules")
        #expect(request.detail == "Remove node_modules directory")
    }

    @Test func stopCarriesTheLastAssistantMessage() throws {
        let event = try #require(try adapter.event(from: Fixture.claudeStop))
        #expect(event.kind == .waitingForReply(lastMessage: "I've completed the refactoring."))
    }

    @Test(arguments: [
        ("idle_prompt", true),
        ("agent_needs_input", true),
        ("permission_prompt", false),
        ("auth_success", false),
    ])
    func notificationsOnlyCountWhenTheAgentWaits(type: String, isWaiting: Bool) throws {
        let event = try adapter.event(from: Fixture.claudeNotification(type: type))
        #expect((event?.kind == .waitingForReply(lastMessage: nil)) == isWaiting)
    }

    @Test func ignoresEventsHaloDoesNotFollow() throws {
        let payload = Data(#"{"session_id":"abc123","hook_event_name":"PreCompact"}"#.utf8)
        #expect(try adapter.event(from: payload) == nil)
    }

    @Test func rejectsPayloadsWithoutASession() {
        #expect(throws: DecodingError.self) {
            try adapter.event(from: Data(#"{"hook_event_name":"Stop"}"#.utf8))
        }
    }

    @Test func allowReplyMatchesTheDocumentedShape() throws {
        let event = try #require(try adapter.event(from: Fixture.claudePermissionRequest))
        let reply = adapter.reply(to: event, decision: .allow)
        #expect(try JSONDecoder().decode(JSONValue.self, from: reply.output) == [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": ["behavior": "allow"],
            ],
        ])
    }

    @Test func denyReplyTellsTheAgentWhy() throws {
        let event = try #require(try adapter.event(from: Fixture.claudePermissionRequest))
        let reply = adapter.reply(to: event, decision: .deny(reason: "Not on main"))
        let decision = try JSONDecoder().decode(JSONValue.self, from: reply.output)["hookSpecificOutput"]?["decision"]
        #expect(decision == ["behavior": "deny", "message": "Not on main"])
    }

    @Test func noDecisionPassesThrough() throws {
        let event = try #require(try adapter.event(from: Fixture.claudePermissionRequest))
        #expect(adapter.reply(to: event, decision: nil).output.isEmpty)
    }

    @Test func codexSharesTheFormatUnderItsOwnNamespace() throws {
        let event = try #require(try ClaudeStyleHookAdapter.codex.event(from: Fixture.claudePermissionRequest))
        #expect(event.tool == .codex)
        #expect(event.sessionID == "codex:abc123")
    }
}
