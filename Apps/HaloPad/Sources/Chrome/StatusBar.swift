import HaloCore
import SwiftUI

/// The thin line across the top: which agent matters, how the Mac is doing, and which Mac.
struct StatusBar: View {
    @Environment(PadModel.self) private var model
    @Environment(MacLink.self) private var link
    @Environment(DashboardStore.self) private var store
    @Environment(Ambience.self) private var ambience

    var body: some View {
        HStack(spacing: 20) {
            AgentIndicator(session: model.leadingAgent) { store.reveal(.agents) }
            Spacer(minLength: 24)
            // The full line when there's room, then the essentials, then nothing: never clipped.
            ViewThatFits(in: .horizontal) {
                MetricsLine(metrics: model.metrics, detail: .full)
                MetricsLine(metrics: model.metrics, detail: .essentials)
                Color.clear.frame(width: 0)
            }
            HStack(spacing: 4) {
                StatusButton(symbol: ambience.isNight ? "moon.fill" : "moon", label: "Night") { ambience.toggleNight() }
                StatusButton(symbol: "slider.horizontal.3", label: "Edit Pages") { store.isEditing = true }
            }
            MacBadge(status: link.status, isLocalNetworkDenied: link.isLocalNetworkDenied) { link.forgetMac() }
        }
        .font(.caption)
        .foregroundStyle(.inkSecondary)
        .padding(.horizontal, 28)
        .frame(height: 44)
    }
}

private struct AgentIndicator: View {
    let session: AgentSession?
    let action: () -> Void

    var body: some View {
        if let session {
            Button(action: action) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(session.needsAttention ? .attention : .progress)
                        .frame(width: 6, height: 6)
                    Text(session.tool.displayName)
                        .foregroundStyle(.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(session.tool.displayName): \(session.title)")
        }
    }
}

private struct MetricsLine: View {
    enum Detail {
        case full, essentials
    }

    let metrics: SystemMetrics
    let detail: Detail

    var body: some View {
        HStack(spacing: 14) {
            Text("CPU \(percent(metrics.cpu))")
            Text("RAM \(percent(metrics.memory))")
            if detail == .full {
                Text("DISK \(bytes(metrics.freeStorageBytes)) FREE")
                Text("NET ↓\(bytes(metrics.networkBytesInPerSecond))/S ↑\(bytes(metrics.networkBytesOutPerSecond))/S")
            }
        }
        .lineLimit(1)
        .fixedSize()
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(0.4)
        .textCase(.uppercase)
        .opacity(metrics.timestamp == .distantPast ? 0 : 1)
    }

    private func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    private func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file, spellsOutZero: false))
    }
}

private struct StatusButton: View {
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct MacBadge: View {
    let status: MacLink.Status
    let isLocalNetworkDenied: Bool
    let forget: () -> Void

    var body: some View {
        Menu {
            Button("Forget This Mac", systemImage: "xmark.circle", role: .destructive, action: forget)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                Text(title)
                    .foregroundStyle(.ink)
                    .lineLimit(1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch status {
        case .connected(let mac): mac.name
        case .searching where isLocalNetworkDenied: String(localized: "Allow Local Network in Settings")
        case .searching(let mac): String(localized: "Looking for \(mac.name)…")
        case .unpaired: String(localized: "Not paired")
        }
    }

    private var dotColor: Color {
        switch status {
        case .connected: .progress
        case .searching where isLocalNetworkDenied: .attention
        default: .inkTertiary
        }
    }
}
