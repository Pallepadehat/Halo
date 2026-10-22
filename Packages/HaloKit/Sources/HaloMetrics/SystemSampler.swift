#if os(macOS)
import Foundation
import HaloCore

/// Turns raw counters into `SystemMetrics`. Each reading is compared with the previous one,
/// so the first call only establishes a baseline.
public struct SystemSampler {
    /// Free space barely moves and the query isn't free; refresh it occasionally.
    static let storageRefreshInterval: Duration = .seconds(30)

    private let clock = ContinuousClock()
    private var previous: (cpu: CPUTicks, network: NetworkTotals, at: ContinuousClock.Instant)?
    private var storage: (usage: StorageUsage, at: ContinuousClock.Instant)?
    private var processes = ProcessReader()
    /// Kept only while the CPU spikes: a culprit needs two readings to measure.
    private var previousProcesses: (snapshot: ProcessSnapshot, at: ContinuousClock.Instant)?

    public init() {}

    public mutating func sample(at date: Date = .now) -> SystemMetrics? {
        let now = clock.now
        guard let cpu = CPUTicks.read(), let network = NetworkTotals.read(), let memory = MemoryUsage.read() else {
            return nil
        }
        defer { previous = (cpu, network, now) }
        guard let previous else { return nil }

        let seconds = (now - previous.at).seconds
        let rate = network.rate(since: previous.network, over: seconds)
        let storage = currentStorage(at: now)

        var metrics = SystemMetrics(
            cpu: cpu.usage(since: previous.cpu),
            memory: memory.share,
            memoryUsedBytes: memory.usedBytes,
            freeStorageBytes: storage?.freeBytes ?? 0,
            totalStorageBytes: storage?.totalBytes ?? 0,
            networkBytesInPerSecond: rate.received,
            networkBytesOutPerSecond: rate.sent,
            timestamp: date
        )
        attachCulprits(to: &metrics, physicalMemory: memory.totalBytes, at: now)
        return metrics
    }

    private mutating func currentStorage(at now: ContinuousClock.Instant) -> StorageUsage? {
        if let storage, now - storage.at < Self.storageRefreshInterval { return storage.usage }
        guard let usage = StorageUsage.read() else { return storage?.usage }
        storage = (usage, now)
        return usage
    }

    /// Walking every process costs a few milliseconds, so it only happens while something spikes.
    private mutating func attachCulprits(to metrics: inout SystemMetrics, physicalMemory: Int64, at now: ContinuousClock.Instant) {
        guard metrics.isCPUSpiking || metrics.isMemorySpiking else {
            previousProcesses = nil
            return
        }

        let snapshot = processes.read()
        if metrics.isMemorySpiking {
            metrics.topMemoryProcess = snapshot.topMemory(physicalBytes: physicalMemory)
        }
        if metrics.isCPUSpiking, let previousProcesses {
            metrics.topCPUProcess = snapshot.topCPU(
                since: previousProcesses.snapshot,
                over: (now - previousProcesses.at).seconds,
                cores: ProcessInfo.processInfo.activeProcessorCount
            )
        }
        previousProcesses = metrics.isCPUSpiking ? (snapshot, now) : nil
    }
}

private extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
#endif
