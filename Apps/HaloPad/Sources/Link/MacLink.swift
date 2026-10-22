import Foundation
import HaloCore
import HaloProtocol
import HaloTransport
import Network
import Observation
import os

/// The iPad's end of the link: finds its paired Mac on the network, keeps an encrypted
/// connection to it alive, and runs pairing when there's no Mac yet.
@MainActor
@Observable
final class MacLink {
    enum Status: Equatable {
        case unpaired
        case searching(DeviceIdentity)
        case connected(DeviceIdentity)
    }

    enum PairingState: Equatable {
        case idle
        case browsing([DiscoveredMac])
        case connecting(DeviceIdentity)
        case confirming(PairingProposal)
        /// The codes matched here; the person still has to confirm on the Mac.
        case waitingForMac(PairingProposal)
        case failed(String)
        /// The iPad can't browse until Local Network access is allowed in Settings.
        case localNetworkDenied
    }

    /// Pause between reconnect attempts, so a Mac that's asleep doesn't cost battery.
    static let reconnectDelay: Duration = .seconds(2)

    let identity: DeviceIdentity
    private(set) var status: Status = .unpaired
    private(set) var pairing: PairingState = .idle
    /// Local Network access is off, so the paired Mac can't be found.
    private(set) var isLocalNetworkDenied = false
    /// The paired Mac is on the network but refuses this iPad's key: it was forgotten on the Mac,
    /// or the helper was reinstalled. Only pairing again helps.
    private(set) var isForgottenByMac = false
    /// Pairing is the first thing to do: there's no Mac yet, or the Mac no longer knows this iPad.
    var needsPairing: Bool { status == .unpaired || isForgottenByMac }
    /// Estimated one-way latency to the Mac, for the PRD's 20 ms p95 budget.
    var latency: LatencyStats { probe.stats }

    @ObservationIgnored var onMessage: (MacMessage) -> Void = { _ in }
    @ObservationIgnored var onDisconnect: () -> Void = {}

    @ObservationIgnored private let store: any PairedDeviceStore
    @ObservationIgnored private var outbox: MessageOutbox<PadMessage>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var pairingTask: Task<Void, Never>?
    @ObservationIgnored private var pendingAnswer: CheckedContinuation<Bool, Never>?
    private var probe = LatencyProbe()
    private static let log = Logger(subsystem: "app.halo", category: "MacLink")
    /// Refused handshakes in a row before deciding the Mac has forgotten this iPad.
    private static let refusalsBeforeForgotten = 3

    init(identity: DeviceIdentity, store: any PairedDeviceStore = KeychainPairedDeviceStore()) {
        self.identity = identity
        self.store = store
        // Decided now, so the first frame is already the right screen.
        if let mac = Self.loadPairing(from: store) { status = .searching(mac.identity) }
    }

    func start() {
        if let mac = Self.loadPairing(from: store) { connect(to: mac) }
    }

    private static func loadPairing(from store: any PairedDeviceStore) -> PairedDevice? {
        do {
            return try store.load().last
        } catch {
            log.error("Could not load pairing: \(error, privacy: .public)")
            return nil
        }
    }

    /// The Keychain outlives the app, so a fresh install would otherwise inherit a pairing the
    /// person has long forgotten, and wait for that Mac instead of asking to pair.
    static func forgetPairingsFromAnEarlierInstall(in store: any PairedDeviceStore = KeychainPairedDeviceStore()) {
        let key = "hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? store.load().forEach { try store.remove($0.id) }
    }

    /// Sends to the Mac if connected. Halo is a live surface, so nothing is queued while offline.
    func send(_ message: PadMessage) {
        outbox?.send(message)
    }

    func forgetMac() {
        connectionTask?.cancel()
        connectionTask = nil
        outbox = nil
        switch status {
        case .searching(let mac), .connected(let mac):
            try? store.remove(mac.id)
        case .unpaired:
            break
        }
        status = .unpaired
        isForgottenByMac = false
        onDisconnect()
    }

    // MARK: - Connection

    private func connect(to mac: PairedDevice) {
        connectionTask?.cancel()
        isForgottenByMac = false
        connectionTask = Task {
            var refusals = 0
            while !Task.isCancelled {
                status = .searching(mac.identity)
                guard let endpoint = await discover(mac.identity) else { return }
                switch await runSession(with: mac, at: endpoint) {
                case .refused:
                    refusals += 1
                    if refusals >= Self.refusalsBeforeForgotten { isForgottenByMac = true }
                case .ended:
                    refusals = 0
                }
                try? await Task.sleep(for: Self.reconnectDelay)
            }
        }
    }

    /// Waits until the paired Mac is advertising. `nil` once cancelled.
    private func discover(_ mac: DeviceIdentity) async -> NWEndpoint? {
        let browser = HaloBrowser(type: HaloService.pairedType)
        browser.start()
        defer { browser.cancel() }
        for await update in browser.updates {
            switch update {
            case .found(let macs):
                isLocalNetworkDenied = false
                if let found = macs.first(where: { $0.id == mac.id }) { return found.endpoint }
            case .localNetworkDenied:
                isLocalNetworkDenied = true
            }
        }
        return nil
    }

    private enum SessionEnd {
        /// The Mac turned down this iPad's key during the handshake.
        case refused
        case ended
    }

    private func runSession(with mac: PairedDevice, at endpoint: NWEndpoint) async -> SessionEnd {
        let channel = NetworkChannel(to: endpoint, using: HaloNetworkParameters.client(for: mac, as: identity))
        defer { channel.close() }
        do {
            try await channel.open()
        } catch NWError.tls(let status) {
            Self.log.notice("The Mac refused the handshake: \(status, privacy: .public)")
            return .refused
        } catch {
            Self.log.debug("Couldn't reach the Mac: \(error, privacy: .public)")
            return .ended
        }
        do {
            let outbox = MessageOutbox<PadMessage>(channel)
            outbox.send(.hello(deviceID: identity.id, deviceName: identity.name, protocolVersion: haloProtocolVersion))
            guard case .hello(_, haloProtocolVersion) = try await channel.receive(MacMessage.self) else {
                Self.log.notice("The Mac speaks a different protocol version")
                return .ended
            }

            self.outbox = outbox
            status = .connected(mac.identity)
            isForgottenByMac = false
            probe = LatencyProbe()
            let pinging = Task {
                while !Task.isCancelled {
                    outbox.send(.ping(id: probe.makePing(at: .now)))
                    try? await Task.sleep(for: LatencyProbe.interval)
                }
            }
            defer {
                pinging.cancel()
                self.outbox = nil
                onDisconnect()
            }

            for try await message in channel.messages(of: MacMessage.self) {
                if case .pong(let id) = message {
                    probe.receivePong(id, at: .now)
                } else {
                    onMessage(message)
                }
            }
        } catch {
            Self.log.debug("Mac session ended: \(error, privacy: .public)")
        }
        return .ended
    }

    // MARK: - Pairing

    func beginPairing() {
        guard pairingTask == nil, pairing == .idle else { return }
        pairing = .browsing([])
        pairingTask = Task {
            let browser = HaloBrowser(type: HaloService.pairingType)
            browser.start()
            defer { browser.cancel() }
            for await update in browser.updates {
                guard pairing.isLookingForMacs else { continue }
                switch update {
                case .found(let macs): pairing = .browsing(macs)
                case .localNetworkDenied: pairing = .localNetworkDenied
                }
            }
        }
    }

    func pair(with mac: DiscoveredMac) {
        pairingTask?.cancel()
        pairing = .connecting(mac.identity)
        pairingTask = Task {
            // A cancelled task has already been replaced; don't clear its successor.
            defer { if !Task.isCancelled { pairingTask = nil } }
            let channel = NetworkChannel(to: mac.endpoint, using: HaloNetworkParameters.pairing())
            defer { channel.close() }
            do {
                try await channel.open()
                let paired = try await PairingSession.initiate(over: channel, as: identity) { proposal in
                    await self.askToConfirm(proposal)
                }
                try store.load().forEach { try store.remove($0.id) }
                try store.save(paired)
                pairing = .idle
                connect(to: paired)
            } catch is CancellationError {
                return
            } catch {
                if pairing != .idle { pairing = .failed(PairingFailure.message(for: error)) }
            }
        }
    }

    func answerPairing(accepted: Bool) {
        if accepted, case .confirming(let proposal) = pairing { pairing = .waitingForMac(proposal) }
        pendingAnswer?.resume(returning: accepted)
        pendingAnswer = nil
    }

    func cancelPairing() {
        answerPairing(accepted: false)
        pairingTask?.cancel()
        pairingTask = nil
        pairing = .idle
    }

    /// Starts over from looking for Macs.
    func restartPairing() {
        cancelPairing()
        beginPairing()
    }

    private func askToConfirm(_ proposal: PairingProposal) async -> Bool {
        pairing = .confirming(proposal)
        return await withCheckedContinuation { pendingAnswer = $0 }
    }
}

private extension MacLink.PairingState {
    var isLookingForMacs: Bool {
        switch self {
        case .browsing, .localNetworkDenied: true
        default: false
        }
    }
}

#if DEBUG
extension MacLink {
    /// A link that looks connected and never touches the network or the real Keychain.
    static func demo() -> MacLink {
        let link = MacLink(
            identity: DeviceIdentity(id: UUID(), name: "Demo iPad"),
            store: KeychainPairedDeviceStore(service: "app.halo.demo")
        )
        link.status = .connected(DemoData.mac)
        return link
    }

    /// `-HaloDemoPairing searching|macs|code|waiting|forgotten` shows one step of pairing.
    static func demoPairing(_ step: String) -> MacLink {
        let link = MacLink(
            identity: DeviceIdentity(id: UUID(), name: "Demo iPad"),
            store: KeychainPairedDeviceStore(service: "app.halo.demo")
        )
        link.status = .unpaired
        let proposal = PairingProposal(peer: DemoData.mac, verificationCode: "048213")
        switch step {
        case "code": link.pairing = .confirming(proposal)
        case "waiting": link.pairing = .waitingForMac(proposal)
        case "forgotten":
            link.isForgottenByMac = true
            link.pairing = .browsing([])
        default: link.pairing = .browsing([])
        }
        return link
    }
}
#endif
