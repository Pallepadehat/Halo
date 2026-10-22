#if os(macOS)
import Darwin

/// Cumulative bytes through the Mac's physical interfaces.
struct NetworkTotals: Equatable {
    var received: UInt64
    var sent: UInt64

    /// Bytes per second since `earlier`. A counter that went backwards (interface reset) reads as zero.
    func rate(since earlier: NetworkTotals, over seconds: Double) -> (received: Int64, sent: Int64) {
        guard seconds > 0 else { return (0, 0) }
        func perSecond(_ now: UInt64, _ before: UInt64) -> Int64 {
            now >= before ? Int64(Double(now - before) / seconds) : 0
        }
        return (perSecond(received, earlier.received), perSecond(sent, earlier.sent))
    }

    /// Only `en*` interfaces (Wi-Fi, Ethernet, USB and Thunderbolt adapters). Virtual ones such as
    /// `utun` (VPN) or `bridge` carry traffic that is already counted on a physical interface.
    static func isCounted(interfaceNamed name: String) -> Bool {
        name.hasPrefix("en")
    }

    /// Reads 64-bit counters via `NET_RT_IFLIST2`; `getifaddrs` only has 32-bit ones, which wrap at 4 GB.
    static func read() -> NetworkTotals? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var totals = NetworkTotals(received: 0, sent: 0)
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                defer { offset += Int(header.ifm_msglen) }

                guard Int32(header.ifm_type) == RTM_IFINFO2,
                      offset + MemoryLayout<if_msghdr2>.size <= length,
                      let name = interfaceName(Int32(header.ifm_index)),
                      isCounted(interfaceNamed: name)
                else { continue }

                let data = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self).ifm_data
                totals.received += data.ifi_ibytes
                totals.sent += data.ifi_obytes
            }
        }
        return totals
    }

    private static func interfaceName(_ index: Int32) -> String? {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &name) != nil else { return nil }
        return String(nulTerminated: name)
    }
}
#endif
