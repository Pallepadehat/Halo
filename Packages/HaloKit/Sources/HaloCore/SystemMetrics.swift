import Foundation

/// A single snapshot of Mac health, shown in the status strip and Pulse.
public struct SystemMetrics: Codable, Sendable, Hashable {
    /// Share of all cores in use, 0...1.
    public var cpu: Double
    /// Share of physical memory in use (app, wired and compressed, as Activity Monitor counts it), 0...1.
    public var memory: Double
    public var memoryUsedBytes: Int64
    public var freeStorageBytes: Int64
    public var totalStorageBytes: Int64
    public var networkBytesInPerSecond: Int64
    public var networkBytesOutPerSecond: Int64
    /// What's eating the CPU. Only reported while `isCPUSpiking`.
    public var topCPUProcess: ProcessUsage?
    /// What's eating memory. Only reported while `isMemorySpiking`.
    public var topMemoryProcess: ProcessUsage?
    public var timestamp: Date

    public init(
        cpu: Double,
        memory: Double,
        memoryUsedBytes: Int64 = 0,
        freeStorageBytes: Int64,
        totalStorageBytes: Int64 = 0,
        networkBytesInPerSecond: Int64,
        networkBytesOutPerSecond: Int64,
        topCPUProcess: ProcessUsage? = nil,
        topMemoryProcess: ProcessUsage? = nil,
        timestamp: Date = .now
    ) {
        self.cpu = cpu
        self.memory = memory
        self.memoryUsedBytes = memoryUsedBytes
        self.freeStorageBytes = freeStorageBytes
        self.totalStorageBytes = totalStorageBytes
        self.networkBytesInPerSecond = networkBytesInPerSecond
        self.networkBytesOutPerSecond = networkBytesOutPerSecond
        self.topCPUProcess = topCPUProcess
        self.topMemoryProcess = topMemoryProcess
        self.timestamp = timestamp
    }

    public static let empty = SystemMetrics(
        cpu: 0, memory: 0, freeStorageBytes: 0,
        networkBytesInPerSecond: 0, networkBytesOutPerSecond: 0,
        timestamp: .distantPast
    )
}

// MARK: - Spikes

public extension SystemMetrics {
    /// Above this, Pulse names the process responsible.
    static let cpuSpikeThreshold = 0.7
    static let memorySpikeThreshold = 0.85
    /// Below this share of free space, storage is flagged.
    static let lowStorageThreshold = 0.1

    var isCPUSpiking: Bool { cpu >= Self.cpuSpikeThreshold }
    var isMemorySpiking: Bool { memory >= Self.memorySpikeThreshold }

    /// Share of the startup volume in use, 0...1.
    var storageUsed: Double {
        guard totalStorageBytes > 0 else { return 0 }
        return 1 - Double(freeStorageBytes) / Double(totalStorageBytes)
    }

    var isStorageLow: Bool {
        totalStorageBytes > 0 && 1 - storageUsed < Self.lowStorageThreshold
    }
}

/// One app's share of a resource, with helper processes folded into their app.
public struct ProcessUsage: Codable, Sendable, Hashable {
    public let name: String
    /// Share of the whole machine's CPU or memory, 0...1.
    public let share: Double

    public init(name: String, share: Double) {
        self.name = name
        self.share = share
    }
}
