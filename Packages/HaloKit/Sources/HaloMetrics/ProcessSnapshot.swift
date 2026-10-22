#if os(macOS)
import Darwin
import Foundation
import HaloCore

/// CPU time and resident memory per app, with helper processes folded into the app they ship in
/// (all of Chrome's renderers count as "Google Chrome").
struct ProcessSnapshot: Equatable {
    var cpuNanoseconds: [String: UInt64] = [:]
    var residentBytes: [String: Int64] = [:]

    /// The app that used the most CPU since `earlier`, as a share of every core.
    func topCPU(since earlier: ProcessSnapshot, over seconds: Double, cores: Int) -> ProcessUsage? {
        let capacity = seconds * Double(cores) * 1_000_000_000
        guard capacity > 0 else { return nil }
        let deltas = cpuNanoseconds.compactMap { name, now -> (String, UInt64)? in
            guard let before = earlier.cpuNanoseconds[name], now > before else { return nil }
            return (name, now - before)
        }
        guard let (name, used) = deltas.max(by: { $0.1 < $1.1 }) else { return nil }
        return ProcessUsage(name: name, share: min(1, Double(used) / capacity))
    }

    /// The app holding the most memory, as a share of physical memory.
    func topMemory(physicalBytes: Int64) -> ProcessUsage? {
        guard physicalBytes > 0, let (name, bytes) = residentBytes.max(by: { $0.value < $1.value }) else { return nil }
        return ProcessUsage(name: name, share: min(1, Double(bytes) / Double(physicalBytes)))
    }

    /// `/Applications/Google Chrome.app/Contents/Frameworks/…/Helper (Renderer).app/…` → `Google Chrome`.
    /// Outside an app bundle, the executable's own name.
    static func displayName(forExecutableAt path: String) -> String {
        let components = path.split(separator: "/")
        if let bundle = components.first(where: { $0.hasSuffix(".app") }) {
            return String(bundle.dropLast(4))
        }
        return components.last.map(String.init) ?? path
    }
}

/// Reads this user's processes. Others' (root daemons, the kernel) are never asked about:
/// without root, `proc_pidinfo` can't describe them and the system logs a warning for each try.
struct ProcessReader {
    private var names: [pid_t: String] = [:]

    mutating func read() -> ProcessSnapshot {
        var snapshot = ProcessSnapshot()
        var seen: Set<pid_t> = []

        for pid in Self.ownPIDs() {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size, let name = name(of: pid) else { continue }

            seen.insert(pid)
            snapshot.cpuNanoseconds[name, default: 0] += MachTime.nanoseconds(info.pti_total_user + info.pti_total_system)
            snapshot.residentBytes[name, default: 0] += Int64(info.pti_resident_size)
        }

        names = names.filter { seen.contains($0.key) }
        return snapshot
    }

    private mutating func name(of pid: pid_t) -> String? {
        if let cached = names[pid] { return cached }
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        let name = ProcessSnapshot.displayName(forExecutableAt: String(nulTerminated: path))
        names[pid] = name
        return name
    }

    private static func ownPIDs() -> [pid_t] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(getuid())]
        var byteCount = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &byteCount, nil, 0) == 0 else { return [] }

        // Leave headroom for processes spawned between the two calls.
        let stride = MemoryLayout<kinfo_proc>.stride
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: byteCount / stride + 32)
        byteCount = processes.count * stride
        guard sysctl(&mib, UInt32(mib.count), &processes, &byteCount, nil, 0) == 0 else { return [] }

        return processes.prefix(byteCount / stride).map(\.kp_proc.p_pid).filter { $0 > 0 }
    }
}

/// `proc_taskinfo` CPU times are in Mach absolute-time units, which aren't nanoseconds on Apple silicon.
enum MachTime {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func nanoseconds(_ ticks: UInt64) -> UInt64 {
        ticks / UInt64(timebase.denom) * UInt64(timebase.numer)
    }
}
#endif
