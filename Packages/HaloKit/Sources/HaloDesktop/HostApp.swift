#if os(macOS)
import AppKit
import Darwin

/// Finds the app an agent runs in (Ghostty, Terminal, iTerm, Cursor…) by walking up from the
/// agent's process to the first ancestor that's a regular, Dock-visible app, and brings it forward.
public enum HostApp {
    @MainActor
    @discardableResult
    public static func activate(containing process: Int32) -> Bool {
        let app = ancestors(of: process, parent: parentProcess).lazy.compactMap { pid in
            NSRunningApplication(processIdentifier: pid).flatMap { $0.activationPolicy == .regular ? $0 : nil }
        }.first
        return app?.activate() ?? false
    }

    /// `process` and its ancestors, nearest first, stopping at launchd or a loop.
    static func ancestors(of process: Int32, parent: (Int32) -> Int32?) -> [Int32] {
        var chain: [Int32] = []
        var current: Int32? = process
        while let pid = current, pid > 1, !chain.contains(pid), chain.count < 64 {
            chain.append(pid)
            current = parent(pid)
        }
        return chain
    }

    private static func parentProcess(of pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }
}
#endif
