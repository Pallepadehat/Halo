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

    init(identity: DeviceIdentity, store: any PairedDeviceStore = KeychainPairedDeviceStore()) {
        self.identity = identity
        self.store = store
    }

    func start() {
        do {
            if let mac = try store.load().last { connect(to: mac) }
        } catch {
            Self.log.error("Could not load pairing: \(error, privacy: .public)")
        }
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
        onDisconnect()
    }

    // MARK: - Connection

    private func connect(to mac: PairedDevice) {
        connectionTask?.cancel()
        connectionTask = Task {
            while !Task.isCancelled {
                status = .searching(mac.identity)
                guard let endpoint = await discover(mac.identity) else { return }
                await runSession(with: mac, at: endpoint)
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

    private func runSession(with mac: PairedDevice, at endpoint: NWEndpoint) async {
        let channel = NetworkChannel(to: endpoint, using: HaloNetworkParameters.client(for: mac, as: identity))
        defer { channel.close() }
        do {
            try await channel.open()
            let outbox = MessageOutbox<PadMessage>(channel)
            outbox.send(.hello(deviceID: identity.id, deviceName: identity.name, protocolVersion: haloProtocolVersion))
            guard case .hello(_, haloProtocolVersion) = try await channel.receive(MacMessage.self) else {
                Self.log.notice("The Mac speaks a different protocol version")
                return
            }

            self.outbox = outbox
            status = .connected(mac.identity)
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
    }

    // MARK: - Pairing

    func beginPairing() {
        guard pairingTask == nil else { return }
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
            defer { pairingTask = nil }
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
        pendingAnswer?.resume(returning: accepted)
        pendingAnswer = nil
    }

    func cancelPairing() {
        answerPairing(accepted: false)
        pairingTask?.cancel()
        pairingTask = nil
        pairing = .idle
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
}
#endif
