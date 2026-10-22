/// Sends messages over a channel strictly in the order they were queued, from synchronous code.
///
/// Spawning a task per send would let messages overtake each other; one long-lived sender
/// keeps the wire order equal to the call order.
public final class MessageOutbox<Message: Encodable & Sendable>: Sendable {
    private let continuation: AsyncStream<Message>.Continuation
    private let sender: Task<Void, Never>

    public init(_ channel: some MessageChannel) {
        let (messages, continuation) = AsyncStream.makeStream(of: Message.self)
        self.continuation = continuation
        sender = Task {
            for await message in messages {
                do {
                    try await channel.send(message)
                } catch {
                    channel.close()
                    return
                }
            }
        }
    }

    deinit {
        finish()
    }

    public func send(_ message: Message) {
        continuation.yield(message)
    }

    /// Stops accepting messages; anything already queued is still sent.
    public func finish() {
        continuation.finish()
    }
}
