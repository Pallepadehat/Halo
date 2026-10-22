#if os(macOS)
import Darwin

/// Cumulative scheduler ticks across all cores. Usage is the busy share between two readings.
struct CPUTicks: Equatable {
    var busy: UInt64
    var total: UInt64

    static func read() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(MachHost.port, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let (user, system, idle, nice) = info.cpu_ticks
        let busy = UInt64(user) + UInt64(system) + UInt64(nice)
        return CPUTicks(busy: busy, total: busy + UInt64(idle))
    }

    /// Busy share of all cores since `earlier`, 0...1.
    func usage(since earlier: CPUTicks) -> Double {
        guard total > earlier.total, busy >= earlier.busy else { return 0 }
        return min(1, Double(busy - earlier.busy) / Double(total - earlier.total))
    }
}

/// `mach_host_self()` hands out a new send right on every call; ask once.
enum MachHost {
    static let port = mach_host_self()
}
#endif
