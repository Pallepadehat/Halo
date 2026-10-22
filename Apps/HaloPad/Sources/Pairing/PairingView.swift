import HaloTransport
import SwiftUI

/// First run: find a Mac running Halo and confirm the code both screens show.
struct PairingView: View {
    @Environment(MacLink.self) private var link

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Image(systemName: "circle.circle")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.haloInk)
                Text("Pair with your Mac")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(.haloInk)
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
                .foregroundStyle(.secondary)
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
                        .background(.haloSurface, in: .rect(cornerRadius: 18))
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
                .foregroundStyle(.secondary)
            Text(proposal.displayCode)
                .font(.system(size: 88, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(.haloInk)
                .accessibilityLabel(proposal.verificationCode.map(String.init).joined(separator: " "))
            HStack(spacing: 16) {
                Button("Cancel") { link.cancelPairing() }
                    .buttonStyle(.bordered)
                Button("Pair") { link.answerPairing(accepted: true) }
                    .buttonStyle(.borderedProminent)
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
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            .buttonStyle(.borderedProminent)
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
                .foregroundStyle(.secondary)
            Button("Try Again") {
                link.cancelPairing()
                link.beginPairing()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
