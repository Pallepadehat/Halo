/// A rolling window of latency samples, summarised the way the PRD's budget is written:
/// p95 under 20 ms.
public struct LatencyStats: Sendable, Equatable {
    public static let capacity = 120

    public private(set) var samples: [Duration] = []

    public init() {}

    public mutating func record(_ sample: Duration) {
        samples.append(sample)
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
    }

    public var p50: Duration? { percentile(0.5) }
    public var p95: Duration? { percentile(0.95) }

    /// Nearest-rank percentile, so every reported value is one that was actually measured.
    public func percentile(_ fraction: Double) -> Duration? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let rank = Int((fraction * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }
}
