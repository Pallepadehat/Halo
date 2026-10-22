import Darwin
import Foundation

/// Blocking whole-message I/O on a stream socket, shared by both ends of the bridge.
enum SocketIO {
    static func write(_ data: Data, to descriptor: Int32) throws(HookBridgeError) {
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

    /// Reads until the peer closes or half-closes its side.
    static func readToEnd(_ descriptor: Int32, limit: Int) throws(HookBridgeError) -> Data {
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
            guard data.count <= limit else { throw .messageTooLarge }
        }
    }

    /// A peer that quits mid-exchange must not kill us with SIGPIPE.
    static func disableSIGPIPE(on descriptor: Int32) {
        var on: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }

    /// Bounds how long a stalled peer can hold a blocking read.
    static func setReadTimeout(_ seconds: Int, on descriptor: Int32) {
        var timeout = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }
}
