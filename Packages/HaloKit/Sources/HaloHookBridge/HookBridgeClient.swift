import Darwin
import Foundation

/// The `halo-hook` side of the bridge: deliberately blocking, synchronous and dependency-free,
/// because it runs once per hook call and must start fast.
public enum HookBridgeClient {
    /// Relays `invocation` to the helper and blocks until it replies.
    ///
    /// The exchange is one request, one reply: we write the request, half-close the socket to mark
    /// its end, then read the reply until the helper closes its side.
    public static func send(
        _ invocation: HookInvocation,
        to socket: URL = HookBridgeLocation.socket
    ) throws(HookBridgeError) -> HookReply {
        let request: Data
        do { request = try JSONEncoder().encode(invocation) } catch { throw .malformedMessage }

        let descriptor = try connect(to: socket)
        defer { close(descriptor) }

        try SocketIO.write(request, to: descriptor)
        guard shutdown(descriptor, SHUT_WR) == 0 else { throw .posix("shutdown") }
        let response = try SocketIO.readToEnd(descriptor, limit: HookBridgeServer.maximumMessageSize)

        do { return try JSONDecoder().decode(HookReply.self, from: response) } catch { throw .malformedMessage }
    }

    private static func connect(to socket: URL) throws(HookBridgeError) -> Int32 {
        let address = try UnixSocketAddress(socket)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .posix("socket") }
        SocketIO.disableSIGPIPE(on: descriptor)

        let result = address.withSockaddr { Darwin.connect(descriptor, $0, $1) }
        guard result == 0 else {
            let error = HookBridgeError.posix("connect")
            close(descriptor)
            throw error
        }
        return descriptor
    }
}
