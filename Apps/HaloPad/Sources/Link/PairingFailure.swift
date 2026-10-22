import Foundation
import HaloTransport

enum PairingFailure {
    static func message(for error: any Error) -> String {
        switch error as? PairingError {
        case .declinedByPeer: String(localized: "Pairing was declined on the Mac.")
        case .declinedLocally: String(localized: "Pairing was cancelled.")
        case .commitmentMismatch, .invalidPublicKey: String(localized: "The connection was tampered with. Try again on a network you trust.")
        case .unexpectedMessage, nil: String(localized: "The Mac stopped responding. Try again.")
        }
    }
}
