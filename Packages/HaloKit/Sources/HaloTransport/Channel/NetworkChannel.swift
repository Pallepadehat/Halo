import Foundation
import Network
import Synchronization

/// A `MessageChannel` over an `NWConnection`: each message is a 4-byte big-endian length
/// followed by its JSON encoding.
public final class NetworkChannel: MessageChannel {
    /// Agent payloads are small; anything bigger than this is a bug or an attack.
    public static let maximumFrameSize = 1 << 20

    public let connection: NWConnection
    private let queue = DispatchQueue(label: "app.halo.channel")

    public init(_ connection: NWConnection) {
        self.connection = connection
    }

    public convenience init(to endpoint: NWEndpoint, using parameters: NWParameters) {
        self.init(NWConnection(to: endpoint, using: parameters))
    }

    /// Starts the connection and returns once it's ready (TLS handshake included).
    public func open() async throws {
        let pending = Mutex<CheckedContinuation<Void, any Error>?>(nil)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.withLock { $0 = continuation }
                connection.stateUpdateHandler = { [connection] state in
                    switch state {
                    case .ready:
                        pending.withLock { $0.take() }?.resume()
                    case .failed(let error), .waiting(let error):
                        // `waiting` means no route right now; callers own the retry policy.
                        pending.withLock { $0.take() }?.resume(throwing: error)
                        connection.cancel()
                    case .cancelled:
                        pending.withLock { $0.take() }?.resume(throwing: ChannelError.closed)
                    default:
                        break
                    }
                }
                connection.start(queue: queue)
            }
        } onCancel: {
            connection.cancel()
        }
    }

    public func send<Message: Encodable & Sendable>(_ message: Message) async throws {
        let body = try JSONEncoder().encode(message)
        guard body.count <= Self.maximumFrameSize else { throw ChannelError.frameTooLarge(body.count) }

        var frame = withUnsafeBytes(of: UInt32(body.count).bigEndian) { Data($0) }
        frame.append(body)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func receive<Message: Decodable & Sendable>(_ type: Message.Type) async throws -> Message {
        let header = try await receive(exactly: 4)
        let length = Int(header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian)
        guard length <= Self.maximumFrameSize else {
            close()
            throw ChannelError.frameTooLarge(length)
        }
        return try JSONDecoder().decode(type, from: try await receive(exactly: length))
    }

    public func close() {
        connection.cancel()
    }

    private func receive(exactly count: Int) async throws -> Data {
        guard count > 0 else { return Data() }
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { content, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content, content.count == count {
                    continuation.resume(returning: content)
                } else {
                    // The peer closed (or half-closed) mid-frame or between frames.
                    continuation.resume(throwing: ChannelError.closed)
                }
            }
        }
    }
}
