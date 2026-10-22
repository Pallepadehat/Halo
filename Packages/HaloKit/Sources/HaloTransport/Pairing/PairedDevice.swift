import CryptoKit
import Foundation

/// A device this one has paired with, and the secret only the two of them know.
public struct PairedDevice: Sendable, Identifiable {
    public let identity: DeviceIdentity
    public let secret: SymmetricKey
    public let pairedAt: Date

    public var id: UUID { identity.id }

    public init(identity: DeviceIdentity, secret: SymmetricKey, pairedAt: Date = .now) {
        self.identity = identity
        self.secret = secret
        self.pairedAt = pairedAt
    }
}

extension PairedDevice: Codable {
    private enum CodingKeys: String, CodingKey {
        case identity, secret, pairedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(DeviceIdentity.self, forKey: .identity)
        secret = SymmetricKey(data: try container.decode(Data.self, forKey: .secret))
        pairedAt = try container.decode(Date.self, forKey: .pairedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity, forKey: .identity)
        try container.encode(secret.withUnsafeBytes { Data($0) }, forKey: .secret)
        try container.encode(pairedAt, forKey: .pairedAt)
    }
}
