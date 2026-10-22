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

        try write(request, to: descriptor)
        guard shutdown(descriptor, SHUT_WR) == 0 else { throw .posix("shutdown") }
        let response = try readToEnd(descriptor)

        do { return try JSONDecoder().decode(HookReply.self, from: response) } catch { throw .malformedMessage }
    }

    private static func connect(to socket: URL) throws(HookBridgeError) -> Int32 {
        let address = try UnixSocketAddress(socket)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw .posix("socket") }

        // A helper that quits mid-reply must not kill the agent's hook process with SIGPIPE.
        var on: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        let result = address.withSockaddr { Darwin.connect(descriptor, $0, $1) }
        guard result == 0 else {
            let error = HookBridgeError.posix("connect")
            close(descriptor)
            throw error
        }
        return descriptor
    }

    private static func write(_ data: Data, to descriptor: Int32) throws(HookBridgeError) {
        var failure: HookBridgeError?
        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(descriptor, buffer.baseAddress! + offset, buffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    failure = .posix("write")
                    return
                }
                offset += written
            }
        }
        if let failure { throw failure }
    }

    private static func readToEnd(_ descriptor: Int32) throws(HookBridgeError) -> Data {
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = read(descriptor, &chunk, chunk.count)
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw .posix("read")
            }
            data.append(contentsOf: chunk[..<count])
            guard data.count <= HookBridgeServer.maximumMessageSize else { throw .messageTooLarge }
        }
    }
}
