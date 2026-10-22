import HaloCore
import SwiftUI

/// Mac health at a glance: one stat tile per metric, each with a ten-minute trend.
struct PulseView: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        let samples = model.pulse.samples

        Grid(horizontalSpacing: 20, verticalSpacing: 20) {
            GridRow {
                StatTile(
                    label: "CPU",
                    value: metrics.cpu.formatted(.percent.precision(.fractionLength(0))),
                    alert: metrics.isCPUSpiking ? .high(culprit: metrics.topCPUProcess) : nil
                ) {
                    Sparkline(samples: samples, domain: 0...1, value: \.cpu, format: .percentage)
                }
                StatTile(
                    label: "Memory",
                    value: metrics.memory.formatted(.percent.precision(.fractionLength(0))),
                    caption: "\(metrics.memoryUsedBytes.formatted(.byteCount(style: .memory))) used",
                    alert: metrics.isMemorySpiking ? .high(culprit: metrics.topMemoryProcess) : nil
                ) {
                    Sparkline(samples: samples, domain: 0...1, value: \.memory, format: .percentage)
                }
            }
            GridRow {
                StatTile(
                    label: "Network",
                    value: "↓ \(metrics.networkBytesInPerSecond.formatted(.byteCount(style: .file)))/s",
                    caption: "↑ \(metrics.networkBytesOutPerSecond.formatted(.byteCount(style: .file)))/s"
                ) {
                    Sparkline(samples: samples, value: \.downloadRate, format: .transferRate)
                }
                StatTile(
                    label: "Storage",
                    value: "\(metrics.freeStorageBytes.formatted(.byteCount(style: .file))) free",
                    caption: "of \(metrics.totalStorageBytes.formatted(.byteCount(style: .file)))",
                    alert: metrics.isStorageLow ? .low : nil
                ) {
                    Meter(fraction: metrics.storageUsed, isAlarming: metrics.isStorageLow)
                }
            }
        }
        .padding(32)
        .animation(.halo, value: metrics.isCPUSpiking)
        .animation(.halo, value: metrics.isMemorySpiking)
    }
}

private extension SystemMetrics {
    var downloadRate: Double { Double(networkBytesInPerSecond) }
}

#Preview(traits: .landscapeLeft) {
    PulseView()
        .environment(PadModel.demo(showing: .pulse))
        .background(.black)
}
