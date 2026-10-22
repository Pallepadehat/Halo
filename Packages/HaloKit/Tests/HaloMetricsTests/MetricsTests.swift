import Foundation
import Testing
import HaloCore
@testable import HaloMetrics

@Suite struct CounterMathTests {
    @Test func cpuUsageIsTheBusyShareBetweenReadings() {
        let earlier = CPUTicks(busy: 100, total: 1000)
        #expect(CPUTicks(busy: 350, total: 1500).usage(since: earlier) == 0.5)
        #expect(earlier.usage(since: earlier) == 0)
    }

    @Test func networkRateIgnoresCountersThatReset() {
        let earlier = NetworkTotals(received: 1_000, sent: 5_000)
        let rate = NetworkTotals(received: 3_000, sent: 100).rate(since: earlier, over: 2)
        #expect(rate.received == 1_000)
        #expect(rate.sent == 0)
    }

    @Test(arguments: [("en0", true), ("en7", true), ("utun3", false), ("lo0", false), ("bridge0", false)])
    func countsOnlyPhysicalInterfaces(name: String, counted: Bool) {
        #expect(NetworkTotals.isCounted(interfaceNamed: name) == counted)
    }
}

@Suite struct ProcessSnapshotTests {
    @Test(arguments: [
        ("/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)", "Google Chrome"),
        ("/Applications/Xcode.app/Contents/MacOS/Xcode", "Xcode"),
        ("/usr/libexec/trustd", "trustd"),
    ])
    func foldsHelpersIntoTheirApp(path: String, name: String) {
        #expect(ProcessSnapshot.displayName(forExecutableAt: path) == name)
    }

    @Test func topCPUIsTheLargestDeltaNotTheLargestTotal() {
        let earlier = ProcessSnapshot(cpuNanoseconds: ["Xcode": 9_000_000_000, "Chrome": 1_000_000_000])
        let now = ProcessSnapshot(cpuNanoseconds: ["Xcode": 9_100_000_000, "Chrome": 4_000_000_000, "New": 1])
        let top = now.topCPU(since: earlier, over: 1, cores: 4)
        #expect(top == ProcessUsage(name: "Chrome", share: 0.75))
    }

    @Test func topMemoryIsAShareOfPhysicalMemory() {
        let snapshot = ProcessSnapshot(residentBytes: ["Safari": 4, "Mail": 1])
        #expect(snapshot.topMemory(physicalBytes: 16) == ProcessUsage(name: "Safari", share: 0.25))
    }
}

/// Reads this Mac's real counters: values must land in sane ranges.
@Suite struct LiveReadingTests {
    @Test func samplerProducesSaneMetrics() async throws {
        var sampler = SystemSampler()
        #expect(sampler.sample() == nil, "The first reading is only a baseline")
        try await Task.sleep(for: .milliseconds(300))

        let sample = sampler.sample()
        let metrics = try #require(sample)
        #expect((0...1).contains(metrics.cpu))
        #expect((0.01...1).contains(metrics.memory))
        #expect(metrics.memoryUsedBytes > 0)
        #expect(metrics.totalStorageBytes > metrics.freeStorageBytes)
        #expect(metrics.networkBytesInPerSecond >= 0)
    }

    @Test func processReaderSeesThisProcess() {
        var reader = ProcessReader()
        let snapshot = reader.read()
        #expect(snapshot.residentBytes.count > 5)
        #expect(snapshot.residentBytes.values.allSatisfy { $0 >= 0 })
    }
}
