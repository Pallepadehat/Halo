import Charts
import HaloCore
import SwiftUI

/// A ten-minute trend for one metric. Press and drag to read any moment.
///
/// The line sits in a recessive ink so the hero number above stays the point; only the
/// current reading is drawn at full strength.
struct Sparkline: View {
    enum Format {
        case percentage
        case transferRate

        func string(for value: Double) -> String {
            switch self {
            case .percentage: value.formatted(.percent.precision(.fractionLength(0)))
            case .transferRate: "\(Int64(value).formatted(.byteCount(style: .file)))/s"
            }
        }
    }

    let samples: [SystemMetrics]
    /// Fixed for shares; `nil` scales to the window's peak (network has no natural ceiling).
    var domain: ClosedRange<Double>?
    let value: KeyPath<SystemMetrics, Double>
    let format: Format

    @State private var selectedDate: Date?

    var body: some View {
        Chart {
            ForEach(samples, id: \.timestamp) { sample in
                AreaMark(x: .value("Time", sample.timestamp), y: .value("Value", sample[keyPath: value]))
                    .foregroundStyle(.linearGradient(
                        colors: [Color.haloInk.opacity(0.16), Color.haloInk.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", sample.timestamp), y: .value("Value", sample[keyPath: value]))
                    .foregroundStyle(Color.haloInk.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }

            if let current = selected ?? samples.last {
                PointMark(x: .value("Time", current.timestamp), y: .value("Value", current[keyPath: value]))
                    .foregroundStyle(Color.haloInk)
                    .symbolSize(70)
            }

            if let selected {
                RuleMark(x: .value("Time", selected.timestamp))
                    .foregroundStyle(Color.haloInk.opacity(0.25))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ScrubLabel(value: format.string(for: selected[keyPath: value]), date: selected.timestamp)
                    }
            }
        }
        .chartXScale(domain: timeDomain)
        .chartYScale(domain: domain ?? 0...max(1, peak))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: $selectedDate)
        .accessibilityLabel("Last ten minutes")
    }

    /// Always the full ten minutes, so a fresh connection fills in from the right.
    private var timeDomain: ClosedRange<Date> {
        let end = samples.last?.timestamp ?? .now
        return end.addingTimeInterval(-MetricsHistory.window)...end
    }

    private var peak: Double {
        samples.map { $0[keyPath: value] }.max() ?? 0
    }

    private var selected: SystemMetrics? {
        guard let selectedDate else { return nil }
        return samples.min { abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate)) }
    }
}

private struct ScrubLabel: View {
    let value: String
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.haloInk)
            Text(date, format: .dateTime.hour().minute().second())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.8), in: .rect(cornerRadius: 10))
    }
}

/// A single ratio against its limit: the fill and its track share one ink.
struct Meter: View {
    let fraction: Double
    var isAlarming = false

    var body: some View {
        VStack {
            Spacer()
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.haloInk.opacity(0.12))
                    Capsule()
                        .fill(isAlarming ? Color.haloAttention : Color.haloInk.opacity(0.6))
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement()
        .accessibilityLabel("Used")
        .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
    }
}
