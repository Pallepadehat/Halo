import Foundation
import Testing
import HaloCore
@testable import HaloAgents

@Suite struct AgentSessionStoreTests {
    private let sessionID = AgentSession.id(tool: .claudeCode, nativeID: "abc123")
    private var store = AgentSessionStore()

    private func event(_ kind: AgentEvent.Kind, at seconds: TimeInterval = 0, session: AgentSession.ID? = nil) -> AgentEvent {
        AgentEvent(
            sessionID: session ?? sessionID,
            tool: .claudeCode,
            kind: kind,
            workingDirectory: "/Users/me/Halo",
            hookEventName: "Test",
            date: Date(timeIntervalSinceReferenceDate: seconds)
        )
    }

    private func approval() -> ApprovalRequest {
        ApprovalRequest(sessionID: sessionID, toolName: "Bash", summary: "npm test")
    }

    @Test mutating func newSessionIsNamedAfterItsProject() throws {
        store.apply(event(.sessionStarted))
        let session = try #require(store[sessionID])
        #expect(session.title == "Halo")
        #expect(session.project == "Halo")
        #expect(session.status == .idle)
    }

    @Test mutating func firstPromptNamesTheSession() throws {
        store.apply(event(.promptSubmitted("Fix the failing tests\nand then lint")))
        store.apply(event(.promptSubmitted("Now update the README")))
        let session = try #require(store[sessionID])
        #expect(session.title == "Fix the failing tests")
        #expect(session.status == .running)
    }

    @Test mutating func longPromptsAreTrimmedToATitle() throws {
        store.apply(event(.promptSubmitted(String(repeating: "a", count: 200))))
        #expect(try #require(store[sessionID]).title.count == AgentSessionStore.maximumTitleLength)
    }

    @Test mutating func answeredApprovalResumesTheSession() throws {
        let request = approval()
        store.apply(event(.approvalRequested(request)))
        #expect(store[sessionID]?.status == .waitingForApproval)
        #expect(store[sessionID]?.pendingApprovals == [request])

        store.removeApproval(request.id, in: sessionID, wasAnswered: true)
        #expect(store[sessionID]?.status == .running)
        #expect(store[sessionID]?.pendingApprovals.isEmpty == true)
    }

    @Test mutating func expiredApprovalKeepsWaitingUntilTheToolRuns() {
        let request = approval()
        store.apply(event(.approvalRequested(request)))
        store.removeApproval(request.id, in: sessionID, wasAnswered: false)
        #expect(store[sessionID]?.status == .waitingForApproval)

        store.apply(event(.toolCompleted))
        #expect(store[sessionID]?.status == .running)
    }

    @Test mutating func waitingForReplyKeepsTheLastKnownMessage() {
        store.apply(event(.waitingForReply(lastMessage: "Done. All tests pass.")))
        store.apply(event(.waitingForReply(lastMessage: nil)))
        #expect(store[sessionID]?.latestMessage == "Done. All tests pass.")
        #expect(store[sessionID]?.status == .waitingForReply)
    }

    @Test mutating func endedSessionsDisappear() {
        store.apply(event(.promptSubmitted("Hello")))
        store.apply(event(.sessionEnded))
        #expect(store.sessions.isEmpty)
    }

    @Test mutating func sessionsThatNeedYouComeFirst() {
        let other = AgentSession.id(tool: .claudeCode, nativeID: "other")
        store.apply(event(.waitingForReply(lastMessage: nil), at: 1))
        store.apply(event(.promptSubmitted("Newer, but busy"), at: 2, session: other))
        #expect(store.sessions.map(\.id) == [sessionID, other])
    }
}
