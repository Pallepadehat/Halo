import CryptoKit
import Foundation
import Network

/// Connection parameters for Halo's two kinds of link.
public enum HaloNetworkParameters {
    /// TLS 1.2 PSK with ephemeral ECDHE: the pairing secret authenticates both ends, ECDHE
    /// gives forward secrecy, ChaCha20-Poly1305 encrypts. (Network.framework doesn't support
    /// external PSKs with TLS 1.3.)
    static let cipherSuite = tls_ciphersuite_t(rawValue: 0xCCAC)! // TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256

    /// The iPad's side of an encrypted link to the Mac it paired with.
    public static func client(for pairing: PairedDevice, as local: DeviceIdentity) -> NWParameters {
        secured(keys: [(identity: local.id, secret: pairing.secret)])
    }

    /// The Mac's side: accepts any iPad it has paired with, and nothing else.
    public static func server(accepting pairings: [PairedDevice]) -> NWParameters {
        secured(keys: pairings.map { (identity: $0.identity.id, secret: $0.secret) })
    }

    /// Unencrypted, used only while the pairing window is open. The pairing protocol itself
    /// authenticates the exchange, and nothing sensitive is sent over it.
    public static func pairing() -> NWParameters {
        let parameters = NWParameters(tls: nil, tcp: tcpOptions())
        parameters.includePeerToPeer = true
        return parameters
    }

    /// Bonjour browsing, including peer-to-peer Wi-Fi for desks without a shared network.
    public static func discovery() -> NWParameters {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        return parameters
    }

    private static func secured(keys: [(identity: UUID, secret: SymmetricKey)]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for key in keys {
            sec_protocol_options_add_pre_shared_key(
                options,
                key.secret.withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData,
                Data(key.identity.uuidString.utf8).withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData
            )
        }
        sec_protocol_options_append_tls_ciphersuite(options, cipherSuite)
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)

        let parameters = NWParameters(tls: tls, tcp: tcpOptions())
        parameters.includePeerToPeer = true
        return parameters
    }

    /// Trackpad events are tiny and latency-critical: never let Nagle batch them.
    private static func tcpOptions() -> NWProtocolTCP.Options {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        return tcp
    }
}
