import Testing
@testable import HaloCore

@Suite struct ModeSuggesterTests {
    let suggester = ModeSuggester()
    let waiting = AgentSession(id: "claude-code:1", tool: .claudeCode, title: "Fix tests", status: .waitingForApproval)

    @Test func surfacesAgentsWhenOneIsWaiting() {
        #expect(suggester.suggest(current: .zen, userOverride: nil, agents: [waiting]) == .agents)
    }

    @Test func staysPutWhenNothingNeedsAttention() {
        var running = waiting
        running.status = .running
        #expect(suggester.suggest(current: .zen, userOverride: nil, agents: [running]) == nil)
    }

    @Test func userOverrideWins() {
        #expect(suggester.suggest(current: .zen, userOverride: .deck, agents: [waiting]) == .deck)
        #expect(suggester.suggest(current: .deck, userOverride: .deck, agents: [waiting]) == nil)
    }
}
