/// An ordered, reliable stream of `Codable` messages between two devices.
///
/// Sends may come from any task. Receives must come from a single reader at a time.
public protocol MessageChannel: Sendable {
    func send<Message: Encodable & Sendable>(_ message: Message) async throws
    func receive<Message: Decodable & Sendable>(_ type: Message.Type) async throws -> Message
    func close()
}

public enum ChannelError: Error, Equatable {
    case closed
    case frameTooLarge(Int)
}

public extension MessageChannel {
    /// Every message until the peer goes away. Ends normally on a clean close, otherwise throws.
    func messages<Message: Decodable & Sendable>(of type: Message.Type) -> AsyncThrowingStream<Message, any Error> {
        AsyncThrowingStream {
            do {
                return try await receive(type)
            } catch ChannelError.closed {
                return nil
            }
        }
    }
}
