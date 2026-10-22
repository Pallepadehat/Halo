import HaloCore
import SwiftUI

// One widget per Mac metric. Small: label, hero number, ring. Tall: a ten-minute trend joins in.

struct ProcessorWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        StatLayout(label: "Processor", symbol: "cpu", trend: \.cpu, samples: model.pulse.samples) {
            HeroValue(value: percent(metrics.cpu), caption: "In use")
        } accessory: {
            RingGauge(fraction: metrics.cpu, symbol: "cpu", isAlarming: metrics.isCPUSpiking)
        } footer: {
            if metrics.isCPUSpiking { Culprit(usage: metrics.topCPUProcess) }
        }
    }
}

struct MemoryWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        StatLayout(label: "Memory", symbol: "memorychip", trend: \.memory, samples: model.pulse.samples) {
            HeroValue(value: percent(metrics.memory), caption: "\(metrics.memoryUsedBytes.formatted(.byteCount(style: .memory))) in use")
        } accessory: {
            RingGauge(fraction: metrics.memory, symbol: "memorychip", isAlarming: metrics.isMemorySpiking)
        } footer: {
            if metrics.isMemorySpiking { Culprit(usage: metrics.topMemoryProcess) }
        }
    }
}

struct StorageWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        StatLayout(label: "Storage", symbol: "internaldrive", trend: nil, samples: []) {
            HeroValue(value: metrics.freeStorageBytes.formatted(.byteCount(style: .file)), caption: "Available of \(metrics.totalStorageBytes.formatted(.byteCount(style: .file)))")
        } accessory: {
            Image(systemName: "internaldrive")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(metrics.isStorageLow ? .attention : .inkSecondary)
        } footer: {
            Meter(fraction: metrics.storageUsed, isAlarming: metrics.isStorageLow)
        }
    }
}

struct NetworkWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        StatLayout(label: "Network", symbol: "network", trend: \.downloadRate, samples: model.pulse.samples, isShare: false) {
            HStack(alignment: .top, spacing: 0) {
                Rate(direction: "Download", symbol: "arrow.down", bytesPerSecond: metrics.networkBytesInPerSecond)
                Rectangle().fill(.inkHairline).frame(width: 1).padding(.vertical, 6).padding(.horizontal, 24)
                Rate(direction: "Upload", symbol: "arrow.up", bytesPerSecond: metrics.networkBytesOutPerSecond)
            }
            .fixedSize(horizontal: false, vertical: true)
        } accessory: {
            EmptyView()
        } footer: {
            EmptyView()
        }
    }
}

// MARK: - Building blocks

private func percent(_ share: Double) -> String {
    share.formatted(.percent.precision(.fractionLength(0)))
}

extension SystemMetrics {
    var downloadRate: Double { Double(networkBytesInPerSecond) }
}

/// Label at the top, value and accessory side by side, an optional trend filling any spare height.
private struct StatLayout<Value: View, Accessory: View, Footer: View>: View {
    let label: LocalizedStringKey
    let symbol: String
    let trend: KeyPath<SystemMetrics, Double>?
    let samples: [SystemMetrics]
    var isShare = true
    @ViewBuilder let value: Value
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let footer: Footer

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 14) {
                Label(label, systemImage: symbol)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.inkSecondary)
                HStack(alignment: .center) {
                    value
                    Spacer(minLength: 16)
                    accessory
                }
                footer
                Spacer(minLength: 0)
                // A calm band, not a chart: it sits under the number, it doesn't compete with it.
                if let trend, geometry.size.height > 260 {
                    Sparkline(samples: samples, domain: isShare ? 0...1 : nil, value: trend, format: isShare ? .percentage : .transferRate)
                        .frame(height: min(geometry.size.height * 0.32, 140))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

private struct HeroValue: View {
    let value: String
    let caption: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.hero(52))
                .foregroundStyle(.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.inkTertiary)
        }
    }
}

private struct Rate: View {
    let direction: LocalizedStringKey
    let symbol: String
    let bytesPerSecond: Int64

    var body: some View {
        let parts = bytesPerSecond.formatted(.byteCount(style: .file)).split(separator: " ", maxSplits: 1)
        VStack(alignment: .leading, spacing: 6) {
            Label(direction, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.inkSecondary)
            Text(parts.first.map(String.init) ?? "0")
                .font(.hero(40))
                .foregroundStyle(.ink)
                .contentTransition(.numericText())
            Text("\(parts.dropFirst().first.map(String.init) ?? "")/s")
                .font(.caption2)
                .foregroundStyle(.inkTertiary)
        }
    }
}

/// A thin ring that fills clockwise, with the metric's symbol inside.
struct RingGauge: View {
    let fraction: Double
    let symbol: String
    var isAlarming = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.14), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0.001), 1))
                .stroke(isAlarming ? Color.attention : Color.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.halo, value: fraction)
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.inkSecondary)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

/// What's eating it. Status is never colour alone: icon, name and share say it too.
private struct Culprit: View {
    let usage: ProcessUsage?

    var body: some View {
        Label {
            if let usage {
                Text("\(usage.name) · \(percent(usage.share))")
            } else {
                Text("Running hot")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.attention)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.ink)
        .transition(.opacity)
    }
}
