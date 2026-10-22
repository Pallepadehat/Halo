import Darwin
import Foundation
import os
import Synchronization

/// The helper side of the bridge: accepts `halo-hook` connections on a Unix domain socket and
/// answers each invocation with whatever `handler` returns.
///
/// Plain POSIX sockets driven by a dispatch source: Network.framework's path evaluation doesn't
/// apply to `AF_UNIX` and logs NECP errors for every connection. Blocking reads and writes run
/// on a dedicated queue, never on Swift's cooperative pool; the handler may take as long as
/// it needs (e.g. while a human decides on the iPad).
public final class HookBridgeServer: Sendable {
    public typealias Handler = @Sendable (HookInvocation) async -> HookReply

    /// Large enough for a `Write` tool call carrying a whole file.
    public static let maximumMessageSize = 8 * 1024 * 1024
    /// `halo-hook` writes its request immediately; anything slower is stuck or hostile.
    static let requestTimeoutSeconds = 5

    private let socket: URL
    private let handler: Handler
    private let acceptQueue = DispatchQueue(label: "app.halo.hook-bridge.accept")
    private let ioQueue = DispatchQueue(label: "app.halo.hook-bridge.io", attributes: .concurrent)
    private let source = Mutex<(any DispatchSourceRead)?>(nil)
    private static let log = Logger(subsystem: "app.halo", category: "HookBridge")

    public init(socket: URL = HookBridgeLocation.socket, handler: @escaping Handler) {
        self.socket = socket
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() throws {
        try prepareSocketPath()
        let descriptor = try listeningSocket()

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: acceptQueue)
        source.setEventHandler { [weak self] in self?.acceptPending(on: descriptor) }
        source.setCancelHandler { close(descriptor) }
        self.source.withLock { $0 = source }
        source.resume()
    }

    public func stop() {
        source.withLock { $0.take() }?.cancel()
        try? FileManager.default.removeItem(at: socket)
    }

    // MARK: - Socket setup

    /// Owner-only directory, and no stale socket file left behind by a previous run.
    private func prepareSocketPath() throws {
        let fileManager = FileManager.default
        let directory = socket.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path(percentEncoded: false))
        if fileManager.fileExists(atPath: socket.path(percentEncoded: false)) {
            try fileManager.removeItem(at: socket)
        }
    }

    private func listeningSocket() throws(HookBridgeError) -> Int32 {
        let address = try UnixSocketAddress(socket)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .posix("socket") }

        do throws(HookBridgeError) {
            guard address.withSockaddr({ bind(descriptor, $0, $1) }) == 0 else { throw .posix("bind") }
            guard listen(descriptor, SOMAXCONN) == 0 else { throw .posix("listen") }
            guard fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK) == 0 else { throw .posix("fcntl") }
        } catch {
            close(descriptor)
            throw error
        }
        return descriptor
    }

    // MARK: - Serving

    private func acceptPending(on descriptor: Int32) {
        while true {
            let client = accept(descriptor, nil, nil)
            guard client >= 0 else { return } // EWOULDBLOCK: drained until the next event.
            SocketIO.disableSIGPIPE(on: client)
            SocketIO.setReadTimeout(Self.requestTimeoutSeconds, on: client)
            serve(client)
        }
    }

    private func serve(_ client: Int32) {
        ioQueue.async { [handler, ioQueue] in
            let invocation: HookInvocation?
            do {
                let request = try SocketIO.readToEnd(client, limit: Self.maximumMessageSize)
                invocation = try JSONDecoder().decode(HookInvocation.self, from: request)
            } catch {
                Self.log.error("Dropping hook invocation: \(String(describing: error), privacy: .public)")
                invocation = nil
            }

            Task {
                let reply = if let invocation { await handler(invocation) } else { HookReply.passThrough }
                ioQueue.async {
                    defer { close(client) }
                    do {
                        try SocketIO.write(JSONEncoder().encode(reply), to: client)
                    } catch {
                        Self.log.error("Could not reply to hook: \(String(describing: error), privacy: .public)")
                    }
                }
            }
        }
    }
}
