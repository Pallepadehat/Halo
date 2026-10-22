import Foundation

/// The rolling window behind Pulse's sparklines.
public struct MetricsHistory: Sendable, Equatable {
    public static let window: TimeInterval = 10 * 60

    public private(set) var samples: [SystemMetrics] = []

    public init(_ samples: [SystemMetrics] = []) {
        replace(with: samples)
    }

    public var latest: SystemMetrics? {
        samples.last
    }

    /// Appends in time order; anything older than the window, measured from the newest sample, is dropped.
    public mutating func append(_ sample: SystemMetrics) {
        guard sample.timestamp >= latest?.timestamp ?? .distantPast else { return }
        samples.append(sample)
        trim()
    }

    public mutating func replace(with samples: [SystemMetrics]) {
        self.samples = samples.sorted { $0.timestamp < $1.timestamp }
        trim()
    }

    private mutating func trim() {
        guard let newest = latest?.timestamp else { return }
        let cutoff = newest.addingTimeInterval(-Self.window)
        if let firstKept = samples.firstIndex(where: { $0.timestamp >= cutoff }), firstKept > 0 {
            samples.removeFirst(firstKept)
        }
    }
}
