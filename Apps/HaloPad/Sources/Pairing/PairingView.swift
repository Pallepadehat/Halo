import HaloTransport
import SwiftUI

/// First run: find a Mac running Halo Helper, then check that both screens show the same code.
/// The person confirms on both devices, so neither can be paired by someone else on the network.
struct PairingView: View {
    @Environment(MacLink.self) private var link

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 44) {
                Header(isForgotten: link.isForgottenByMac)
                content
                    .frame(maxWidth: 560)
                    .frame(minHeight: 260, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .id(link.pairing.step)
            }
            .padding(48)
        }
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
            Connecting(mac: mac.name)
        case .confirming(let proposal):
            ConfirmCode(proposal: proposal)
        case .waitingForMac(let proposal):
            WaitingForMac(proposal: proposal)
        case .failed(let message):
            PairingFailed(message: message)
        case .localNetworkDenied:
            LocalNetworkDenied()
        }
    }
}

private extension MacLink.PairingState {
    /// Which screen of the flow this is, so a new step crossfades in while a list updates in place.
    var step: Int {
        switch self {
        case .idle, .browsing([]): 0
        case .browsing: 1
        case .connecting: 2
        case .confirming: 3
        case .waitingForMac: 4
        case .failed: 5
        case .localNetworkDenied: 6
        }
    }
}

private struct Header: View {
    let isForgotten: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image("HaloIcon")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                .accessibilityHidden(true)
            Text(isForgotten ? "Pair Again" : "Pair with Your Mac")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.ink)
            if isForgotten {
                Text("Your Mac no longer recognises this iPad.")
                    .font(.title3)
                    .foregroundStyle(.inkSecondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}

private struct SearchingForMacs: View {
    var body: some View {
        VStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 18) {
                Step(number: 1, text: "Open **Halo Helper** on your Mac.")
                Step(number: 2, text: "Click Halo in the menu bar, then choose **Pair iPad**.")
                Step(number: 3, text: "Your Mac appears here. Tap it to continue.")
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 28, style: .continuous))

            HStack(spacing: 10) {
                ProgressView()
                Text("Looking for Macs nearby")
            }
            .font(.subheadline)
            .foregroundStyle(.inkSecondary)
        }
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(number, format: .number)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.ink)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.14), in: .circle)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 8 }
            Text(text)
                .font(.title3)
                .foregroundStyle(.ink)
        }
    }
}

private struct MacList: View {
    @Environment(MacLink.self) private var link
    let macs: [DiscoveredMac]

    var body: some View {
        VStack(spacing: 18) {
            Text("Choose your Mac")
                .eyebrowStyle()
            VStack(spacing: 10) {
                ForEach(macs) { mac in
                    Button {
                        link.pair(with: mac)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "laptopcomputer")
                                .font(.system(size: 26, weight: .light))
                                .frame(width: 44)
                            Text(mac.identity.name)
                                .font(.title3.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.inkTertiary)
                        }
                        .foregroundStyle(.ink)
                        .padding(.horizontal, 22)
                        .frame(height: 72)
                        .contentShape(.rect)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ConfirmCode: View {
    @Environment(MacLink.self) private var link
    let proposal: PairingProposal

    var body: some View {
        VStack(spacing: 32) {
            Text("Check that **\(proposal.peer.name)** shows this code.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            CodeDigits(code: proposal)
            HStack(spacing: 14) {
                Button("Cancel", action: link.restartPairing)
                    .buttonStyle(.glass)
                Button("The Codes Match") { link.answerPairing(accepted: true) }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.extraLarge)
        }
    }
}

/// This iPad has said yes; pairing finishes when the person says yes on the Mac too.
private struct WaitingForMac: View {
    @Environment(MacLink.self) private var link
    let proposal: PairingProposal

    var body: some View {
        VStack(spacing: 32) {
            Text("Now click **Pair** on \(proposal.peer.name).")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.ink)
            CodeDigits(code: proposal)
                .opacity(0.5)
            HStack(spacing: 10) {
                ProgressView()
                Text("Waiting for your Mac")
            }
            .font(.subheadline)
            .foregroundStyle(.inkSecondary)
            Button("Cancel", action: link.restartPairing)
                .buttonStyle(.glass)
                .controlSize(.large)
        }
    }
}

/// The six digits, each on its own glass tile, so they're easy to compare at a glance.
private struct CodeDigits: View {
    let code: PairingProposal

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(code.verificationCode.enumerated()), id: \.offset) { index, digit in
                Text(String(digit))
                    .font(.hero(56))
                    .foregroundStyle(.ink)
                    .frame(width: 68, height: 88)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
                    .padding(.leading, index == 3 ? 14 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(code.verificationCode.map(String.init).joined(separator: " "))
    }
}

private struct Connecting: View {
    let mac: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(mac)…")
                .font(.title3)
                .foregroundStyle(.inkSecondary)
        }
        .padding(.top, 40)
    }
}

private struct LocalNetworkDenied: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Label("Halo needs Local Network access to find your Mac.", systemImage: "network.slash")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            Button("Open Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        }
    }
}

private struct PairingFailed: View {
    @Environment(MacLink.self) private var link
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.inkSecondary)
            Button("Try Again", action: link.restartPairing)
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        }
    }
}
