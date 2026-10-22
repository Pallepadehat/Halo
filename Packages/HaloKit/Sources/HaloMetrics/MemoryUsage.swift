#if os(macOS)
import Darwin
import Foundation

/// Memory in use the way Activity Monitor counts it: app memory + wired + compressed.
struct MemoryUsage: Equatable {
    var usedBytes: Int64
    var totalBytes: Int64

    var share: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }

    static func read() -> MemoryUsage? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(MachHost.port, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let appPages = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
        let usedPages = appPages + Int64(stats.wire_count) + Int64(stats.compressor_page_count)
        return MemoryUsage(
            usedBytes: usedPages * Int64(getpagesize()),
            totalBytes: Int64(ProcessInfo.processInfo.physicalMemory)
        )
    }
}
#endif
