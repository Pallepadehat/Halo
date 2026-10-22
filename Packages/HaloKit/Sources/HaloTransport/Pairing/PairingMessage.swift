import Foundation

/// The pairing wire format. Only ever sent over the short-lived pairing channel.
enum PairingMessage: Codable, Sendable {
    case initiatorHello(identity: DeviceIdentity, publicKey: Data)
    case responderHello(identity: DeviceIdentity, publicKey: Data, commitment: Data)
    case nonce(Data)
    case confirmation(accepted: Bool)

}
