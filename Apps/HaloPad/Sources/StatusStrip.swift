import SwiftUI

struct StatusStrip: View {
    @Environment(PadModel.self) private var model
    @Environment(MacLink.self) private var link

    var body: some View {
        HStack(spacing: 24) {
            ConnectionLabel(status: link.status, isLocalNetworkDenied: link.isLocalNetworkDenied)
                .contextMenu {
                    Button("Forget This Mac", systemImage: "xmark.circle", role: .destructive) {
                        link.forgetMac()
                    }
                }
            Spacer()
            Text("CPU \(model.metrics.cpu, format: .percent.precision(.fractionLength(0)))")
            Text("RAM \(model.metrics.memory, format: .percent.precision(.fractionLength(0)))")
            Text("\(model.metrics.freeStorageBytes, format: .byteCount(style: .file)) free")
            Text("↓ \(model.metrics.networkBytesInPerSecond, format: .byteCount(style: .file))/s")
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

private struct ConnectionLabel: View {
    let status: MacLink.Status
    let isLocalNetworkDenied: Bool

    var body: some View {
        switch status {
        case .searching where isLocalNetworkDenied:
            Label("Allow Local Network for Halo in Settings", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.haloAttention)
        case .connected(let mac):
            Label(mac.name, systemImage: "laptopcomputer")
        case .searching(let mac):
            Label("Looking for \(mac.name)…", systemImage: "laptopcomputer.slash")
                .foregroundStyle(.tertiary)
        case .unpaired:
            Label("Not paired", systemImage: "laptopcomputer.slash")
        }
    }
}
