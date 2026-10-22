import Testing
@testable import HaloCore

@Suite struct ModeSuggesterTests {
    let suggester = ModeSuggester()
    let running = AgentSession(id: "claude-code:1", tool: .claudeCode, title: "Fix tests", status: .running)

    var waiting: AgentSession {
        var session = running
        session.status = .waitingForApproval
        session.pendingApprovals = [ApprovalRequest(sessionID: session.id, toolName: "Bash", summary: "npm test")]
        return session
    }

    @Test func surfacesAgentsWhenOneStartsWaiting() {
        #expect(suggester.suggestion(showing: .zen, previous: [running], current: [waiting]) == .agents)
    }

    @Test func staysPutWhileNothingNeedsAttention() {
        #expect(suggester.suggestion(showing: .zen, previous: [], current: [running]) == nil)
    }

    @Test func respectsLeavingAgentsWhileTheSameRequestWaits() {
        let request = waiting
        #expect(suggester.suggestion(showing: .deck, previous: [request], current: [request]) == nil)
    }

    @Test func surfacesAgainForANewRequest() {
        let first = waiting
        var second = first
        second.pendingApprovals.append(ApprovalRequest(sessionID: first.id, toolName: "Edit", summary: "App.swift"))
        #expect(suggester.suggestion(showing: .deck, previous: [first], current: [second]) == .agents)
    }

    @Test func neverSuggestsTheModeYouAreIn() {
        #expect(suggester.suggestion(showing: .agents, previous: [running], current: [waiting]) == nil)
    }
}
