import HaloTransport
import SwiftUI

/// First run: find a Mac running Halo and confirm the code both screens show.
struct PairingView: View {
    @Environment(MacLink.self) private var link

    var body: some View {
        ZStack {
            Backdrop()
            pairing
        }
    }

    private var pairing: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Image(systemName: "circle.circle")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.ink)
                Text("Pair with your Mac")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.ink)
            }

            content
                .frame(maxWidth: 520)
                .transition(.opacity)
        }
        .padding(48)
        .animation(.halo, value: link.pairing)
        .onAppear { link.beginPairing() }
    }

    @ViewBuilder
    private var content: some View {
        switch link.pairing {
        case .idle, .browsing([]):
            SearchingForMacs()
        case .browsing(let macs):
            MacList(macs: macs)
        case .connecting(let mac):
            ProgressView("Connecting to \(mac.name)…")
        case .confirming(let proposal):
            ConfirmCode(proposal: proposal)
        case .failed(let message):
            PairingFailed(message: message)
        case .localNetworkDenied:
            LocalNetworkDenied()
        }
    }
}

private struct SearchingForMacs: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("On your Mac, open Halo from the menu bar and choose **Pair iPad**.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
        }
    }
}

private struct MacList: View {
    @Environment(MacLink.self) private var link
    let macs: [DiscoveredMac]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(macs) { mac in
                Button {
                    link.pair(with: mac)
                } label: {
                    Label(mac.identity.name, systemImage: "laptopcomputer")
                        .font(.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ConfirmCode: View {
    @Environment(MacLink.self) private var link
    let proposal: PairingProposal

    var body: some View {
        VStack(spacing: 28) {
            Text("Make sure \(proposal.peer.name) shows the same code.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            Text(proposal.displayCode)
                .font(.hero(96))
                .foregroundStyle(.ink)
                .accessibilityLabel(proposal.verificationCode.map(String.init).joined(separator: " "))
            HStack(spacing: 16) {
                Button("Cancel") { link.cancelPairing() }
                    .buttonStyle(.glass)
                Button("Pair") { link.answerPairing(accepted: true) }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.extraLarge)
        }
    }
}

private struct LocalNetworkDenied: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Text("Halo needs Local Network access to find your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            Button("Open Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }
}

private struct PairingFailed: View {
    @Environment(MacLink.self) private var link
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            Button("Try Again") {
                link.cancelPairing()
                link.beginPairing()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }
}
