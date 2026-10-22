import Foundation
import Network
import os

/// The helper side of the bridge: accepts `halo-hook` connections on a Unix domain socket and
/// answers each invocation with whatever `handler` returns.
///
/// The handler may take as long as it needs (e.g. while a human decides on the iPad);
/// every connection is served independently.
public final class HookBridgeServer: Sendable {
    public typealias Handler = @Sendable (HookInvocation) async -> HookReply

    /// Large enough for a `Write` tool call carrying a whole file.
    public static let maximumMessageSize = 8 * 1024 * 1024

    private let socket: URL
    private let handler: Handler
    private let listener: NWListener
    private let queue = DispatchQueue(label: "app.halo.hook-bridge")
    private static let log = Logger(subsystem: "app.halo", category: "HookBridge")

    public init(socket: URL = HookBridgeLocation.socket, handler: @escaping Handler) throws {
        self.socket = socket
        self.handler = handler

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: socket.path(percentEncoded: false))
        listener = try NWListener(using: parameters)
    }

    public func start() throws {
        try prepareSocketPath()
        listener.newConnectionHandler = { [handler, queue] connection in
            Task { await Self.serve(connection, on: queue, with: handler) }
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                Self.log.error("Hook bridge listener failed: \(error, privacy: .public)")
            }
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener.cancel()
        try? FileManager.default.removeItem(at: socket)
    }

    /// Owner-only directory, and no stale socket file left behind by a previous run.
    private func prepareSocketPath() throws {
        let directory = socket.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path(percentEncoded: false))
        if FileManager.default.fileExists(atPath: socket.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: socket)
        }
    }

    private static func serve(_ connection: NWConnection, on queue: DispatchQueue, with handler: Handler) async {
        connection.start(queue: queue)
        defer { connection.cancel() }

        let reply: HookReply
        do {
            let request = try await connection.receiveToEnd(limit: maximumMessageSize)
            reply = await handler(try JSONDecoder().decode(HookInvocation.self, from: request))
        } catch {
            log.error("Dropping hook invocation: \(error, privacy: .public)")
            reply = .passThrough
        }

        do {
            try await connection.sendFinal(JSONEncoder().encode(reply))
        } catch {
            log.error("Could not reply to hook: \(error, privacy: .public)")
        }
    }
}

private extension NWConnection {
    /// Reads until the peer half-closes its side.
    func receiveToEnd(limit: Int) async throws -> Data {
        var data = Data()
        while true {
            let (chunk, isComplete) = try await receiveChunk()
            if let chunk { data.append(chunk) }
            guard data.count <= limit else { throw HookBridgeError.messageTooLarge }
            if isComplete { return data }
        }
    }

    private func receiveChunk() async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (content, isComplete))
                }
            }
        }
    }

    func sendFinal(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            send(content: data, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
