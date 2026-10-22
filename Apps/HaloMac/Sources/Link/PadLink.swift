import Foundation
import HaloProtocol
import HaloTransport
import Observation
import os

/// The Mac's end of the iPad link: accepts paired iPads over the encrypted service, runs the
/// on-demand pairing window, and fans state out to every connected iPad.
@MainActor
@Observable
final class PadLink {
    enum PairingState: Equatable {
        case idle
        case waitingForPad
        case confirming(PairingProposal)
        case failed(String)
    }

    /// How long the pairing service stays discoverable once opened.
    static let pairingWindow: Duration = .seconds(120)

    let identity: DeviceIdentity
    private(set) var pairedPads: [DeviceIdentity] = []
    private(set) var connectedPads: Set<DeviceIdentity.ID> = []
    private(set) var pairing: PairingState = .idle
    /// Local Network access is off, so iPads can't find this Mac. Cleared by the next successful listen.
    private(set) var isLocalNetworkDenied = false

    /// Messages every iPad receives right after connecting, so it starts in sync.
    @ObservationIgnored var snapshot: () -> [MacMessage] = { [] }
    @ObservationIgnored var onMessage: (PadMessage) -> Void = { _ in }

    @ObservationIgnored private let store: any PairedDeviceStore
    @ObservationIgnored private var pairings: [PairedDevice] = []
    @ObservationIgnored private var listener: HaloListener?
    @ObservationIgnored private var peers: [DeviceIdentity.ID: Peer] = [:]
    @ObservationIgnored private var pairingTask: Task<Void, Never>?
    @ObservationIgnored private var pendingAnswer: CheckedContinuation<Bool, Never>?
    private static let log = Logger(subsystem: "app.halo", category: "PadLink")

    private struct Peer {
        let channel: NetworkChannel
        let outbox: MessageOutbox<MacMessage>
    }

    init(identity: DeviceIdentity, store: any PairedDeviceStore = KeychainPairedDeviceStore()) {
        self.identity = identity
        self.store = store
    }

    func start() {
        do {
            pairings = try store.load()
        } catch {
            Self.log.error("Could not load pairings: \(error, privacy: .public)")
        }
        pairedPads = pairings.map(\.identity)
        restartListener()
    }

    func broadcast(_ message: MacMessage) {
        for peer in peers.values {
            peer.outbox.send(message)
        }
    }

    func forget(_ pad: DeviceIdentity) {
        do {
            try store.remove(pad.id)
        } catch {
            Self.log.error("Could not forget \(pad.name, privacy: .public): \(error, privacy: .public)")
            return
        }
        pairings.removeAll { $0.id == pad.id }
        pairedPads = pairings.map(\.identity)
        peers[pad.id]?.channel.close()
        restartListener()
    }

    // MARK: - Paired connections

    /// The TLS-PSK key set is fixed per listener, so pairing changes mean a new listener.
    /// Established connections are unaffected.
    private func restartListener() {
        listener?.cancel()
        listener = nil
        guard !pairings.isEmpty else { return }

        do {
            let listener = try HaloListener(
                advertising: HaloService.pairedType,
                as: identity,
                using: HaloNetworkParameters.server(accepting: pairings)
            )
            self.listener = listener
            Task {
                do {
                    try await listener.start()
                    isLocalNetworkDenied = false
                } catch {
                    isLocalNetworkDenied = error.isLocalNetworkDenied
                    Self.log.error("Paired listener failed: \(error, privacy: .public)")
                    return
                }
                for await channel in listener.connections {
                    Task { await self.serve(channel) }
                }
            }
        } catch {
            Self.log.error("Could not create paired listener: \(error, privacy: .public)")
        }
    }

    private func serve(_ channel: NetworkChannel) async {
        defer { channel.close() }
        do {
            try await channel.open()
            guard case .hello(let padID, _, haloProtocolVersion) = try await channel.receive(PadMessage.self) else {
                Self.log.notice("Dropping an iPad that speaks a different protocol version")
                return
            }

            let outbox = MessageOutbox<MacMessage>(channel)
            outbox.send(.hello(macName: identity.name, protocolVersion: haloProtocolVersion))
            snapshot().forEach(outbox.send)

            peers[padID] = Peer(channel: channel, outbox: outbox)
            connectedPads.insert(padID)
            defer {
                peers[padID] = nil
                connectedPads.remove(padID)
            }

            for try await message in channel.messages(of: PadMessage.self) {
                onMessage(message)
            }
        } catch {
            Self.log.debug("iPad session ended: \(error, privacy: .public)")
        }
    }

    // MARK: - Pairing

    /// Opens the pairing service until an iPad pairs, someone cancels, or the window lapses.
    func beginPairing() {
        guard pairingTask == nil else { return }
        if isLocalNetworkDenied { restartListener() }
        pairing = .waitingForPad
        pairingTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.acceptOnePairing() }
                group.addTask { try? await Task.sleep(for: Self.pairingWindow) }
                await group.next()
                group.cancelAll()
            }
            if pairing == .waitingForPad { pairing = .idle }
            pairingTask = nil
        }
    }

    func answerPairing(accepted: Bool) {
        pendingAnswer?.resume(returning: accepted)
        pendingAnswer = nil
    }

    func cancelPairing() {
        answerPairing(accepted: false)
        pairingTask?.cancel()
        pairing = .idle
    }

    func dismissPairingFailure() {
        if case .failed = pairing { pairing = .idle }
    }

    private func acceptOnePairing() async {
        do {
            let listener = try HaloListener(advertising: HaloService.pairingType, as: identity, using: HaloNetworkParameters.pairing())
            defer { listener.cancel() }
            try await listener.start()
            isLocalNetworkDenied = false

            for await channel in listener.connections {
                defer { channel.close() }
                try await channel.open()
                let pad = try await PairingSession.respond(over: channel, as: identity) { proposal in
                    await self.askToConfirm(proposal)
                }
                try remember(pad)
                pairing = .idle
                return
            }
        } catch is CancellationError {
            return
        } catch {
            isLocalNetworkDenied = error.isLocalNetworkDenied
            if pairing != .idle { pairing = .failed(PairingFailure.message(for: error)) }
        }
    }

    private func askToConfirm(_ proposal: PairingProposal) async -> Bool {
        pairing = .confirming(proposal)
        return await withCheckedContinuation { pendingAnswer = $0 }
    }

    private func remember(_ pad: PairedDevice) throws {
        try store.save(pad)
        pairings.removeAll { $0.id == pad.id }
        pairings.append(pad)
        pairedPads = pairings.map(\.identity)
        restartListener()
    }
}
