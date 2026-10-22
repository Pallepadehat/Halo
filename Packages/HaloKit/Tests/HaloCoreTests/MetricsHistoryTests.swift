import Foundation
import Testing
@testable import HaloCore

@Suite struct MetricsHistoryTests {
    private func sample(at seconds: TimeInterval, cpu: Double = 0.2) -> SystemMetrics {
        SystemMetrics(
            cpu: cpu, memory: 0.5, freeStorageBytes: 100, totalStorageBytes: 1000,
            networkBytesInPerSecond: 0, networkBytesOutPerSecond: 0,
            timestamp: Date(timeIntervalSinceReferenceDate: seconds)
        )
    }

    @Test func keepsTenMinutesFromTheNewestSample() {
        var history = MetricsHistory()
        for second in stride(from: 0, through: 900, by: 2) {
            history.append(sample(at: TimeInterval(second)))
        }
        #expect(history.samples.first?.timestamp == Date(timeIntervalSinceReferenceDate: 300))
        #expect(history.latest?.timestamp == Date(timeIntervalSinceReferenceDate: 900))
    }

    @Test func ignoresSamplesThatArriveOutOfOrder() {
        var history = MetricsHistory([sample(at: 10)])
        history.append(sample(at: 5))
        #expect(history.samples.count == 1)
    }

    @Test func replacingSortsAndTrims() {
        let history = MetricsHistory([sample(at: 1000), sample(at: 0), sample(at: 700)])
        #expect(history.samples.map(\.timestamp.timeIntervalSinceReferenceDate) == [700, 1000])
    }

    @Test func flagsSpikesAndLowStorage() {
        var metrics = sample(at: 0, cpu: 0.95)
        metrics.freeStorageBytes = 50
        #expect(metrics.isCPUSpiking)
        #expect(!metrics.isMemorySpiking)
        #expect(metrics.storageUsed == 0.95)
        #expect(metrics.isStorageLow)
    }
}
