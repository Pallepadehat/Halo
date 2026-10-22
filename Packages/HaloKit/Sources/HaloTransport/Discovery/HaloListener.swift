import Foundation
import Network
import os
import Synchronization

/// Advertises a Halo service and hands out a channel for every incoming connection.
public final class HaloListener: Sendable {
    public let connections: AsyncStream<NetworkChannel>

    private let listener: NWListener
    private let continuation: AsyncStream<NetworkChannel>.Continuation
    private let queue = DispatchQueue(label: "app.halo.listener")
    private static let log = Logger(subsystem: "app.halo", category: "HaloListener")

    /// - Parameter port: `.any` in production; tests pin nothing and read `port` back.
    public init(
        advertising type: String?,
        as identity: DeviceIdentity,
        using parameters: NWParameters,
        port: NWEndpoint.Port = .any
    ) throws {
        listener = try NWListener(using: parameters, on: port)
        if let type {
            listener.service = HaloService.advertisement(type: type, for: identity)
        }
        (connections, continuation) = AsyncStream.makeStream()
    }

    /// Starts listening and returns once the port is bound.
    public func start() async throws {
        listener.newConnectionHandler = { [continuation] connection in
            continuation.yield(NetworkChannel(connection))
        }
        try await withCheckedThrowingContinuation { (ready: CheckedContinuation<Void, any Error>) in
            let pending = Mutex(Optional(ready))
            listener.stateUpdateHandler = { [continuation] state in
                switch state {
                case .ready:
                    pending.withLock { $0.take() }?.resume()
                case .failed(let error):
                    Self.log.error("Listener failed: \(error, privacy: .public)")
                    pending.withLock { $0.take() }?.resume(throwing: error)
                    continuation.finish()
                case .cancelled:
                    pending.withLock { $0.take() }?.resume(throwing: ChannelError.closed)
                    continuation.finish()
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    public var port: NWEndpoint.Port? {
        listener.port
    }

    public func cancel() {
        listener.cancel()
    }
}
