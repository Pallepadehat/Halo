import HaloCore
import SwiftUI

/// Why a metric wants attention.
enum MetricAlert: Equatable {
    /// Spiking, with the app responsible when the Mac could name one.
    case high(culprit: ProcessUsage?)
    case low
}

/// Label, a value readable from arm's length, an optional caption, and a trend beneath.
struct StatTile<Trend: View>: View {
    let label: LocalizedStringKey
    let value: String
    var caption: String?
    var alert: MetricAlert?
    @ViewBuilder let trend: Trend

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let alert {
                    AlertBadge(alert: alert)
                        .transition(.opacity)
                }
            }

            Text(value)
                .font(.system(size: 52, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.haloInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            Text(caption ?? " ")
                .font(.callout)
                .foregroundStyle(.secondary)

            trend
                .frame(minHeight: 96, maxHeight: .infinity, alignment: .bottom)
                .padding(.top, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.haloSurface, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

/// Status is never colour alone: an icon and words carry it too.
private struct AlertBadge: View {
    let alert: MetricAlert

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.haloAttention)
            Text(text)
                .foregroundStyle(.haloInk)
        }
        .font(.subheadline.weight(.medium))
    }

    private var text: String {
        switch alert {
        case .high(let culprit?):
            String(localized: "\(culprit.name) · \(culprit.share.formatted(.percent.precision(.fractionLength(0))))")
        case .high(nil):
            String(localized: "High")
        case .low:
            String(localized: "Almost full")
        }
    }
}
