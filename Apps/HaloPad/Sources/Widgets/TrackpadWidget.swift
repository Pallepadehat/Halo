import HaloCore
import SwiftUI

/// A Mac trackpad of any size, anywhere on any page.
struct TrackpadWidget: View {
    @Environment(PadModel.self) private var model
    @Environment(DashboardStore.self) private var store

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        Group {
            if model.isTrackpadAvailable {
                TrackpadSurface { events in
                    model.send(events)
                } onTouchingChanged: { isTouching in
                    store.isWidgetCapturingTouches = isTouching
                }
                .overlay(alignment: .bottomLeading) {
                    Label("Trackpad", systemImage: "hand.point.up.left")
                        .font(.caption)
                        .foregroundStyle(.inkTertiary)
                        .padding(20)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomTrailing) {
                    #if DEBUG
                    LatencyReadout(stats: model.link.latency)
                        .padding(20)
                        .allowsHitTesting(false)
                    #endif
                }
            } else {
                WidgetUnavailable(symbol: "hand.point.up.left", message: "Choose Allow under Trackpad in Halo on your Mac.")
            }
        }
        .glassEffect(.regular, in: shape)
        .clipShape(shape)
    }
}

/// Debug builds only: the PRD asks for a latency readout while the transport is tuned.
private struct LatencyReadout: View {
    let stats: LatencyStats

    /// The PRD's budget, iPad to Mac at p95.
    private static let budget: Duration = .milliseconds(20)

    var body: some View {
        Text(summary)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(stats.p95.map { $0 > Self.budget } == true ? .attention : .inkTertiary)
    }

    private var summary: String {
        guard let p50 = stats.p50, let p95 = stats.p95 else { return String(localized: "Measuring…") }
        return String(localized: "≈ \(milliseconds(p50)) ms p50 · \(milliseconds(p95)) ms p95")
    }

    private func milliseconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        return (Double(seconds) * 1000 + Double(attoseconds) / 1e15).formatted(.number.precision(.fractionLength(1)))
    }
}
