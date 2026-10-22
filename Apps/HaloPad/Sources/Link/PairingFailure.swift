import Foundation
import HaloTransport

enum PairingFailure {
    static func message(for error: any Error) -> String {
        if error.isLocalNetworkDenied {
            return String(localized: "Halo needs Local Network access to find your Mac. Turn it on in Settings › Privacy & Security › Local Network.")
        }
        return switch error as? PairingError {
        case .declinedByPeer: String(localized: "Pairing was declined on the Mac.")
        case .declinedLocally: String(localized: "Pairing was cancelled.")
        case .commitmentMismatch, .invalidPublicKey: String(localized: "The connection was tampered with. Try again on a network you trust.")
        case .unexpectedMessage, nil: String(localized: "The Mac stopped responding. Try again.")
        }
    }
}
