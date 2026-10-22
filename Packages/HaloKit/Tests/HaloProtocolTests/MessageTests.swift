import Testing
import HaloCore
@testable import HaloProtocol

@Suite struct MessageTests {
    @Test func padMessageRoundTrips() throws {
        let message = PadMessage.agentAction(sessionID: "abc", action: .reply("Yes, go ahead"))
        let data = try MessageCoder.encode(message)
        #expect(try MessageCoder.decode(PadMessage.self, from: data) == message)
    }

    @Test func macMessageRoundTrips() throws {
        let message = MacMessage.metrics(.empty)
        let data = try MessageCoder.encode(message)
        #expect(try MessageCoder.decode(MacMessage.self, from: data) == message)
    }
}
