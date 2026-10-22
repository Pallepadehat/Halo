import CryptoKit
import Foundation
import Network
import Testing
@testable import HaloTransport

/// Real loopback connections through Network.framework.
@Suite struct SecureLinkTests {
    let pad = DeviceIdentity(id: UUID(), name: "iPad")
    let mac = DeviceIdentity(id: UUID(), name: "Mac")
    let secret = SymmetricKey(size: .bits256)

    struct Ping: Codable, Sendable, Equatable {
        let text: String
    }

    private func startServer(accepting pairings: [PairedDevice]) async throws -> HaloListener {
        let listener = try HaloListener(advertising: nil, as: mac, using: HaloNetworkParameters.server(accepting: pairings))
        try await listener.start()
        return listener
    }

    private func localEndpoint(_ listener: HaloListener) throws -> NWEndpoint {
        .hostPort(host: .ipv6(.loopback), port: try #require(listener.port))
    }

    @Test func pairedPadExchangesEncryptedMessages() async throws {
        let listener = try await startServer(accepting: [PairedDevice(identity: pad, secret: secret)])
        defer { listener.cancel() }

        let server = Task {
            for await channel in listener.connections {
                try await channel.open()
                let ping = try await channel.receive(Ping.self)
                try await channel.send(Ping(text: ping.text.uppercased()))
            }
        }
        defer { server.cancel() }

        let pairing = PairedDevice(identity: mac, secret: secret)
        let client = NetworkChannel(to: try localEndpoint(listener), using: HaloNetworkParameters.client(for: pairing, as: pad))
        defer { client.close() }
        try await client.open()
        try await client.send(Ping(text: "hello"))
        #expect(try await client.receive(Ping.self) == Ping(text: "HELLO"))
    }

    @Test func unpairedDeviceIsTurnedAway() async throws {
        let listener = try await startServer(accepting: [PairedDevice(identity: pad, secret: secret)])
        defer { listener.cancel() }
        Task { for await channel in listener.connections { try? await channel.open() } }

        let stranger = PairedDevice(identity: mac, secret: SymmetricKey(size: .bits256))
        let client = NetworkChannel(to: try localEndpoint(listener), using: HaloNetworkParameters.client(for: stranger, as: pad))
        await #expect(throws: (any Error).self) { try await client.open() }
    }

    @Test func pairingWorksOverARealConnection() async throws {
        let listener = try HaloListener(advertising: nil, as: mac, using: HaloNetworkParameters.pairing())
        try await listener.start()
        defer { listener.cancel() }

        let macSide = Task {
            for await channel in listener.connections {
                try await channel.open()
                return try await PairingSession.respond(over: channel, as: mac, confirm: { _ in true })
            }
            throw ChannelError.closed
        }

        let client = NetworkChannel(to: try localEndpoint(listener), using: HaloNetworkParameters.pairing())
        try await client.open()
        let padPairing = try await PairingSession.initiate(over: client, as: pad, confirm: { _ in true })
        #expect(try await macSide.value.secret == padPairing.secret)
    }

    @Test func closedPeerEndsTheMessageStream() async throws {
        let listener = try HaloListener(advertising: nil, as: mac, using: HaloNetworkParameters.pairing())
        try await listener.start()
        defer { listener.cancel() }
        let server = Task {
            for await channel in listener.connections {
                try await channel.open()
                try await channel.send(Ping(text: "bye"))
                channel.close()
            }
        }
        defer { server.cancel() }

        let client = NetworkChannel(to: try localEndpoint(listener), using: HaloNetworkParameters.pairing())
        try await client.open()
        var received: [Ping] = []
        do {
            for try await ping in client.messages(of: Ping.self) { received.append(ping) }
        } catch {
            // A reset instead of a clean close is fine too; what matters is that it ends.
        }
        #expect(received == [Ping(text: "bye")])
    }
}
