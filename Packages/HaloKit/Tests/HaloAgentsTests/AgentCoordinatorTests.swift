import Foundation
import Testing
import HaloCore
import HaloHookBridge
@testable import HaloAgents

@Suite struct AgentCoordinatorTests {
    private let permissionRequest = HookInvocation(tool: .claudeCode, payload: Fixture.claudePermissionRequest)

    @Test func answerFromHaloIsRelayedToTheAgent() async throws {
        let coordinator = AgentCoordinator(approvalWindow: .seconds(30))
        async let reply = coordinator.handle(permissionRequest)

        let request = try await firstPendingApproval(in: coordinator)
        await coordinator.resolve(request.id, with: .allow)

        let decision = try JSONDecoder().decode(JSONValue.self, from: await reply.output)["hookSpecificOutput"]?["decision"]
        #expect(decision == ["behavior": "allow"])
        #expect(await coordinator.sessions.first?.status == .running)
    }

    @Test func unansweredRequestFallsBackToTheAgentsOwnPrompt() async {
        let coordinator = AgentCoordinator(approvalWindow: .milliseconds(50))
        let reply = await coordinator.handle(permissionRequest)
        #expect(reply == .passThrough)
        #expect(await coordinator.sessions.first?.pendingApprovals.isEmpty == true)
    }

    @Test func withoutAWindowRequestsPassStraightThrough() async {
        let coordinator = AgentCoordinator(approvalWindow: nil)
        #expect(await coordinator.handle(permissionRequest) == .passThrough)
    }

    @Test func unknownToolsAndMalformedPayloadsPassThrough() async {
        let coordinator = AgentCoordinator(adapters: [CursorHookAdapter()])
        #expect(await coordinator.handle(permissionRequest) == .passThrough)
        #expect(await coordinator.handle(HookInvocation(tool: .cursor, payload: Data("nope".utf8))) == .passThrough)
        #expect(await coordinator.sessions.isEmpty)
    }

    @Test func publishesEveryChange() async throws {
        let coordinator = AgentCoordinator()
        _ = await coordinator.handle(HookInvocation(tool: .claudeCode, payload: Fixture.claudePrompt))

        var updates = coordinator.sessionUpdates.makeAsyncIterator()
        let sessions = try #require(await updates.next())
        #expect(sessions.map(\.title) == ["Fix the failing tests"])
    }

    /// Waits for the coordinator to register the request the hook is blocked on.
    private func firstPendingApproval(in coordinator: AgentCoordinator) async throws -> ApprovalRequest {
        for await sessions in coordinator.sessionUpdates {
            if let request = sessions.first?.pendingApprovals.first { return request }
        }
        throw CancellationError()
    }
}
