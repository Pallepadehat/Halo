import Testing
@testable import HaloCore

@Suite struct LatencyStatsTests {
    @Test func reportsNearestRankPercentiles() {
        var stats = LatencyStats()
        for milliseconds in 1...100 { stats.record(.milliseconds(milliseconds)) }
        #expect(stats.p50 == .milliseconds(50))
        #expect(stats.p95 == .milliseconds(95))
    }

    @Test func keepsOnlyTheMostRecentWindow() {
        var stats = LatencyStats()
        for _ in 0..<LatencyStats.capacity { stats.record(.milliseconds(100)) }
        for _ in 0..<LatencyStats.capacity { stats.record(.milliseconds(2)) }
        #expect(stats.p95 == .milliseconds(2))
    }

    @Test func isEmptyUntilMeasured() {
        #expect(LatencyStats().p50 == nil)
    }
}
