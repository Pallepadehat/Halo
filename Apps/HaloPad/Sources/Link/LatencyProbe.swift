import HaloCore

/// Measures the link by timing ping/pong round trips. Pings ride the same connection and
/// queues as pointer events, so the estimate reflects what a finger actually experiences.
///
/// One-way latency is estimated as half the round trip: the devices don't share a clock, and
/// Wi-Fi is close enough to symmetric for a budget check.
struct LatencyProbe {
    static let interval: Duration = .seconds(1)
    /// A pong this late is a lost ping; stop waiting for it.
    static let timeout: Duration = .seconds(5)

    private(set) var stats = LatencyStats()
    private var nextID: UInt32 = 0
    private var outstanding: [UInt32: ContinuousClock.Instant] = [:]

    mutating func makePing(at now: ContinuousClock.Instant) -> UInt32 {
        outstanding = outstanding.filter { now - $0.value < Self.timeout }
        nextID &+= 1
        outstanding[nextID] = now
        return nextID
    }

    mutating func receivePong(_ id: UInt32, at now: ContinuousClock.Instant) {
        guard let sent = outstanding.removeValue(forKey: id) else { return }
        stats.record((now - sent) / 2)
    }
}
