import Foundation
@testable import HaloTransport

/// A connected pair of in-process channels, for exercising protocols without a network.
final class InMemoryChannel: MessageChannel {
    private let outbox: AsyncStream<Data>.Continuation
    private let inbox: AsyncStream<Data>
    private let reader: Reader

    /// `AsyncStream` iterators aren't shareable, so a single actor owns ours.
    private actor Reader {
        private var iterator: AsyncStream<Data>.Iterator
        init(_ stream: AsyncStream<Data>) { iterator = stream.makeAsyncIterator() }
        func next() async -> Data? {
            // Iterators share their stream's storage, so advancing a copy advances the stream.
            var copy = iterator
            defer { iterator = copy }
            return await copy.next(isolation: self)
        }
    }

    private init(outbox: AsyncStream<Data>.Continuation, inbox: AsyncStream<Data>) {
        self.outbox = outbox
        self.inbox = inbox
        reader = Reader(inbox)
    }

    static func pair() -> (InMemoryChannel, InMemoryChannel) {
        let (aToB, aToBContinuation) = AsyncStream.makeStream(of: Data.self)
        let (bToA, bToAContinuation) = AsyncStream.makeStream(of: Data.self)
        return (
            InMemoryChannel(outbox: aToBContinuation, inbox: bToA),
            InMemoryChannel(outbox: bToAContinuation, inbox: aToB)
        )
    }

    func send<Message: Encodable & Sendable>(_ message: Message) async throws {
        outbox.yield(try JSONEncoder().encode(message))
    }

    func receive<Message: Decodable & Sendable>(_ type: Message.Type) async throws -> Message {
        guard let data = await reader.next() else { throw ChannelError.closed }
        return try JSONDecoder().decode(type, from: data)
    }

    func close() {
        outbox.finish()
    }
}
