import Testing
@testable import HaloCore

@Suite struct AgentAttentionTests {
    let running = AgentSession(id: "claude-code:1", tool: .claudeCode, title: "Fix tests", status: .running)

    var waiting: AgentSession {
        var session = running
        session.status = .waitingForApproval
        session.pendingApprovals = [ApprovalRequest(sessionID: session.id, toolName: "Bash", summary: "npm test")]
        return session
    }

    @Test func reactsWhenAnAgentStartsWaiting() {
        #expect(AgentAttention.isNewlyNeeded(previous: [running], current: [waiting]))
    }

    @Test func staysQuietWhileNothingNeedsYou() {
        #expect(!AgentAttention.isNewlyNeeded(previous: [], current: [running]))
    }

    @Test func staysQuietWhileTheSameRequestWaits() {
        let request = waiting
        #expect(!AgentAttention.isNewlyNeeded(previous: [request], current: [request]))
    }

    @Test func reactsAgainForANewRequest() {
        let first = waiting
        var second = first
        second.pendingApprovals.append(ApprovalRequest(sessionID: second.id, toolName: "Edit", summary: "App.swift"))
        #expect(AgentAttention.isNewlyNeeded(previous: [first], current: [second]))
    }
}
