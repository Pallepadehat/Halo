import CryptoKit
import Foundation

/// What the person pairing is asked to check: does the other screen show the same code?
public struct PairingProposal: Sendable, Equatable {
    public let peer: DeviceIdentity
    public let verificationCode: String
}

public enum PairingError: Error, Equatable {
    /// The responder's nonce doesn't match its commitment: someone is tampering with the exchange.
    case commitmentMismatch
    case declinedLocally
    case declinedByPeer
    case invalidPublicKey
    /// The peer sent something out of order: not a Halo device, or a broken one.
    case unexpectedMessage
}

/// Runs the pairing exchange over a channel. The iPad initiates, the Mac responds.
///
/// ```
/// initiator                                  responder
///   hello(identity, Ka)            ──▶
///                                  ◀──  hello(identity, Kb), commit(Nb)
///   nonce(Na)                      ──▶
///                                  ◀──  nonce(Nb)
///   both show code(Ka, Kb, Na, Nb), both people confirm
///   confirm(accepted)              ◀─▶  confirm(accepted)
/// ```
public enum PairingSession {
    /// Asks the local person whether both screens show `proposal.verificationCode`.
    public typealias Confirmation = @Sendable (PairingProposal) async -> Bool

    public static func initiate(
        over channel: some MessageChannel,
        as local: DeviceIdentity,
        confirm: Confirmation
    ) async throws -> PairedDevice {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let nonce = PairingCryptography.makeNonce()

        try await channel.send(PairingMessage.initiatorHello(identity: local, publicKey: key.publicKey.rawRepresentation))
        guard case .responderHello(let peer, let peerKey, let commitment) = try await channel.receive(PairingMessage.self) else {
            throw PairingError.unexpectedMessage
        }
        try await channel.send(PairingMessage.nonce(nonce))
        guard case .nonce(let peerNonce) = try await channel.receive(PairingMessage.self) else {
            throw PairingError.unexpectedMessage
        }

        let localKey = key.publicKey.rawRepresentation
        guard PairingCryptography.isValid(commitment: commitment, to: peerNonce, initiatorKey: localKey, responderKey: peerKey) else {
            throw PairingError.commitmentMismatch
        }

        let code = PairingCryptography.verificationCode(
            initiatorKey: localKey, responderKey: peerKey, initiatorNonce: nonce, responderNonce: peerNonce
        )
        try await confirmWithBothPeople(PairingProposal(peer: peer, verificationCode: code), over: channel, confirm: confirm)

        let secret = PairingCryptography.pairingSecret(
            sharedSecret: try key.sharedSecret(with: peerKey),
            initiatorNonce: nonce, responderNonce: peerNonce,
            initiator: local, responder: peer
        )
        return PairedDevice(identity: peer, secret: secret)
    }

    public static func respond(
        over channel: some MessageChannel,
        as local: DeviceIdentity,
        confirm: Confirmation
    ) async throws -> PairedDevice {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let nonce = PairingCryptography.makeNonce()
        let localKey = key.publicKey.rawRepresentation

        guard case .initiatorHello(let peer, let peerKey) = try await channel.receive(PairingMessage.self) else {
            throw PairingError.unexpectedMessage
        }
        let commitment = PairingCryptography.commitment(to: nonce, initiatorKey: peerKey, responderKey: localKey)
        try await channel.send(PairingMessage.responderHello(identity: local, publicKey: localKey, commitment: commitment))
        guard case .nonce(let peerNonce) = try await channel.receive(PairingMessage.self) else {
            throw PairingError.unexpectedMessage
        }
        try await channel.send(PairingMessage.nonce(nonce))

        let code = PairingCryptography.verificationCode(
            initiatorKey: peerKey, responderKey: localKey, initiatorNonce: peerNonce, responderNonce: nonce
        )
        try await confirmWithBothPeople(PairingProposal(peer: peer, verificationCode: code), over: channel, confirm: confirm)

        let secret = PairingCryptography.pairingSecret(
            sharedSecret: try key.sharedSecret(with: peerKey),
            initiatorNonce: peerNonce, responderNonce: nonce,
            initiator: peer, responder: local
        )
        return PairedDevice(identity: peer, secret: secret)
    }

    /// Both people must accept. Each side sends its answer before waiting for the other's,
    /// so neither blocks the other.
    private static func confirmWithBothPeople(
        _ proposal: PairingProposal,
        over channel: some MessageChannel,
        confirm: Confirmation
    ) async throws {
        let accepted = await confirm(proposal)
        try await channel.send(PairingMessage.confirmation(accepted: accepted))
        guard accepted else { throw PairingError.declinedLocally }

        guard case .confirmation(let peerAccepted) = try await channel.receive(PairingMessage.self) else {
            throw PairingError.unexpectedMessage
        }
        guard peerAccepted else { throw PairingError.declinedByPeer }
    }
}

private extension Curve25519.KeyAgreement.PrivateKey {
    func sharedSecret(with rawPublicKey: Data) throws -> SharedSecret {
        guard let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawPublicKey) else {
            throw PairingError.invalidPublicKey
        }
        return try sharedSecretFromKeyAgreement(with: publicKey)
    }
}
