import Foundation
import Testing
import HaloCore
@testable import HaloProtocol

@Suite struct MessageTests {
    @Test func padMessageRoundTrips() throws {
        let message = PadMessage.resolveApproval(id: UUID(), decision: .deny(reason: "Not on main"))
        let data = try MessageCoder.encode(message)
        #expect(try MessageCoder.decode(PadMessage.self, from: data) == message)
    }

    @Test func macMessageRoundTrips() throws {
        let message = MacMessage.metrics(.empty)
        let data = try MessageCoder.encode(message)
        #expect(try MessageCoder.decode(MacMessage.self, from: data) == message)
    }
}
