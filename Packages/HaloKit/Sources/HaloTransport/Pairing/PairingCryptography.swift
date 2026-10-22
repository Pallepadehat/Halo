import CryptoKit
import Foundation

/// The maths behind pairing: Bluetooth-style numeric comparison over X25519.
///
/// The responder commits to its nonce before seeing the initiator's, so a man in the middle
/// has to fix its values before it can learn what the two screens will show. Its best attack
/// is a one-in-a-million guess, and the person pairing sees mismatched codes.
enum PairingCryptography {
    static let nonceByteCount = 16

    static func makeNonce() -> Data {
        SymmetricKey(size: .init(bitCount: nonceByteCount * 8)).withUnsafeBytes { Data($0) }
    }

    static func commitment(to nonce: Data, initiatorKey: Data, responderKey: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: initiatorKey + responderKey, using: SymmetricKey(data: nonce)))
    }

    static func isValid(commitment: Data, to nonce: Data, initiatorKey: Data, responderKey: Data) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(
            commitment,
            authenticating: initiatorKey + responderKey,
            using: SymmetricKey(data: nonce)
        )
    }

    /// The six digits both screens show, e.g. `"048213"`.
    static func verificationCode(initiatorKey: Data, responderKey: Data, initiatorNonce: Data, responderNonce: Data) -> String {
        let digest = SHA256.hash(data: Data("halo.pairing.code".utf8) + initiatorKey + responderKey + initiatorNonce + responderNonce)
        let value = digest.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        let code = String(value % 1_000_000)
        return String(repeating: "0", count: 6 - code.count) + code
    }

    /// The long-term secret that keys every future connection between the two devices.
    static func pairingSecret(
        sharedSecret: SharedSecret,
        initiatorNonce: Data,
        responderNonce: Data,
        initiator: DeviceIdentity,
        responder: DeviceIdentity
    ) -> SymmetricKey {
        sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: initiatorNonce + responderNonce,
            sharedInfo: Data("halo.pairing.secret|\(initiator.id)|\(responder.id)".utf8),
            outputByteCount: 32
        )
    }
}
