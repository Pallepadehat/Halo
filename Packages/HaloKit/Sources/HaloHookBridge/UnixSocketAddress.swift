import Darwin
import Foundation

/// A `sockaddr_un` for a filesystem path, validated against the kernel's path limit.
struct UnixSocketAddress {
    private var storage = sockaddr_un()

    init(_ url: URL) throws(HookBridgeError) {
        let path = Array(url.path(percentEncoded: false).utf8)
        let capacity = MemoryLayout.size(ofValue: storage.sun_path)
        guard path.count < capacity else { throw .socketPathTooLong(url) }

        storage.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &storage.sun_path) { $0.copyBytes(from: path) }
    }

    func withSockaddr<Result>(_ body: (UnsafePointer<sockaddr>, socklen_t) -> Result) -> Result {
        withUnsafePointer(to: storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
