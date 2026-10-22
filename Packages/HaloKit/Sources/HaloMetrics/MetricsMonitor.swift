#if os(macOS)
import HaloCore

public enum MetricsMonitor {
    /// Often enough for a live sparkline, rare enough to stay off Activity Monitor's top list.
    public static let interval: Duration = .seconds(2)

    /// A sample every `interval`, sampled off the main thread, until the stream is dropped.
    public static func samples(every interval: Duration = Self.interval) -> AsyncStream<SystemMetrics> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let sampling = Task.detached(priority: .utility) {
                var sampler = SystemSampler()
                while !Task.isCancelled {
                    if let sample = sampler.sample() { continuation.yield(sample) }
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in sampling.cancel() }
        }
    }
}
#endif
