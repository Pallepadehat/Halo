import Foundation
import Testing
import HaloCore
@testable import HaloAgents

@Suite struct CursorHookAdapterTests {
    let adapter = CursorHookAdapter()

    @Test func promptStartsATurn() throws {
        let event = try #require(try adapter.event(from: Fixture.cursorPrompt))
        #expect(event.sessionID == "cursor:conv-1")
        #expect(event.kind == .promptSubmitted("Add a dark mode toggle"))
        #expect(event.workingDirectory == "/Users/me/Halo")
    }

    @Test func promptReplyLetsThePromptThrough() throws {
        let event = try #require(try adapter.event(from: Fixture.cursorPrompt))
        let reply = adapter.reply(to: event, decision: .allow)
        #expect(try JSONDecoder().decode(JSONValue.self, from: reply.output) == ["continue": true])
    }

    @Test func neverGatesShellCommands() throws {
        let payload = Data(#"{"conversation_id":"conv-1","hook_event_name":"beforeShellExecution","command":"ls"}"#.utf8)
        #expect(try adapter.event(from: payload) == nil)
    }
}
