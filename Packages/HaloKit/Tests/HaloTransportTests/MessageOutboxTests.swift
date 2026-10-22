import Testing
@testable import HaloTransport

@Suite struct MessageOutboxTests {
    @Test func deliversInTheOrderMessagesWereQueued() async throws {
        let (sending, receiving) = InMemoryChannel.pair()
        let outbox = MessageOutbox<Int>(sending)
        for number in 0..<500 { outbox.send(number) }

        var received: [Int] = []
        for _ in 0..<500 { received.append(try await receiving.receive(Int.self)) }
        #expect(received == Array(0..<500))
    }
}
