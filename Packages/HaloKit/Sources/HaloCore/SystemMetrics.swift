import Foundation

/// A single snapshot of Mac health, shown in the status strip and Pulse.
public struct SystemMetrics: Codable, Sendable, Equatable {
    /// 0...1
    public var cpu: Double
    /// 0...1
    public var memory: Double
    public var freeStorageBytes: Int64
    public var networkBytesInPerSecond: Int64
    public var networkBytesOutPerSecond: Int64
    public var topProcess: String?
    public var timestamp: Date

    public init(
        cpu: Double,
        memory: Double,
        freeStorageBytes: Int64,
        networkBytesInPerSecond: Int64,
        networkBytesOutPerSecond: Int64,
        topProcess: String? = nil,
        timestamp: Date = .now
    ) {
        self.cpu = cpu
        self.memory = memory
        self.freeStorageBytes = freeStorageBytes
        self.networkBytesInPerSecond = networkBytesInPerSecond
        self.networkBytesOutPerSecond = networkBytesOutPerSecond
        self.topProcess = topProcess
        self.timestamp = timestamp
    }

    public static let empty = SystemMetrics(
        cpu: 0, memory: 0, freeStorageBytes: 0,
        networkBytesInPerSecond: 0, networkBytesOutPerSecond: 0
    )
}
