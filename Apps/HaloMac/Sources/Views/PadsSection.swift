import HaloTransport
import SwiftUI

struct PadsSection: View {
    @Environment(PadLink.self) private var pads

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("iPad")
            switch pads.pairing {
            case .idle:
                PairedPadsList()
            case .waitingForPad:
                WaitingForPad()
            case .confirming(let proposal):
                ConfirmPairing(proposal: proposal)
            case .failed(let message):
                PairingFailed(message: message)
            }
        }
    }
}

private struct PairedPadsList: View {
    @Environment(PadLink.self) private var pads

    var body: some View {
        ForEach(pads.pairedPads) { pad in
            HStack(spacing: 8) {
                Circle()
                    .fill(pads.connectedPads.contains(pad.id) ? .green : .secondary)
                    .frame(width: 7, height: 7)
                Text(pad.name)
                Spacer()
                Button("Forget", role: .destructive) { pads.forget(pad) }
                    .buttonStyle(.link)
                    .controlSize(.small)
            }
        }
        Button(pads.pairedPads.isEmpty ? "Pair iPad…" : "Pair Another iPad…") { pads.beginPairing() }
    }
}

private struct WaitingForPad: View {
    @Environment(PadLink.self) private var pads

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Open Halo on your iPad and choose this Mac.")
                .foregroundStyle(.secondary)
        }
        Button("Cancel") { pads.cancelPairing() }
    }
}

private struct ConfirmPairing: View {
    @Environment(PadLink.self) private var pads
    let proposal: PairingProposal

    var body: some View {
        Text("Pair with \(proposal.peer.name) if it shows the same code:")
            .foregroundStyle(.secondary)
        Text(proposal.displayCode)
            .font(.system(size: 34, weight: .light, design: .rounded).monospacedDigit())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        HStack {
            Button("Cancel") { pads.cancelPairing() }
            Spacer()
            Button("Pair") { pads.answerPairing(accepted: true) }
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct PairingFailed: View {
    @Environment(PadLink.self) private var pads
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.red)
        Button("OK") { pads.dismissPairingFailure() }
    }
}
