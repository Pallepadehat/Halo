import HaloCore
import HaloProtocol
import SwiftUI

/// The iPad as a large Mac trackpad.
struct TrackpadView: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        if model.isTrackpadAvailable {
            TrackpadSurface { events in model.send(events) }
                .background(.haloSurface, in: .rect(cornerRadius: 32))
                .padding(24)
                .overlay(alignment: .bottomTrailing) {
                    #if DEBUG
                    LatencyReadout(stats: model.link.latency)
                        .padding(40)
                    #endif
                }
                // Edge swipes belong to the trackpad here, not to the system.
                .defersSystemGestures(on: .all)
        } else {
            ContentUnavailableView(
                "Allow pointer control on your Mac",
                systemImage: "hand.point.up.left",
                description: Text("Open Halo from your Mac's menu bar and choose **Allow** under Trackpad.")
            )
        }
    }
}

/// Debug builds only: the PRD asks for a latency readout while the transport is tuned.
private struct LatencyReadout: View {
    let stats: LatencyStats

    var body: some View {
        Text(summary)
            .font(.caption.monospacedDigit())
            .foregroundStyle(isOverBudget ? .haloAttention : .secondary)
    }

    /// The PRD's budget, iPad to Mac at p95.
    private static let budget: Duration = .milliseconds(20)

    private var isOverBudget: Bool {
        stats.p95.map { $0 > Self.budget } ?? false
    }

    private var summary: String {
        guard let p50 = stats.p50, let p95 = stats.p95 else { return String(localized: "Measuring latency…") }
        return String(localized: "≈ \(milliseconds(p50)) ms p50 · \(milliseconds(p95)) ms p95")
    }

    private func milliseconds(_ duration: Duration) -> String {
        (Double(duration.components.attoseconds) / 1e15 + Double(duration.components.seconds) * 1000)
            .formatted(.number.precision(.fractionLength(1)))
    }
}

#Preview(traits: .landscapeLeft) {
    TrackpadView()
        .environment(PadModel.demo(showing: .trackpad))
        .background(.black)
}
