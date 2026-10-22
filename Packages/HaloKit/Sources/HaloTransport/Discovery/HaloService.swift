import Foundation
import Network

/// Halo's Bonjour services. Both must be listed under `NSBonjourServices` in each app.
public enum HaloService {
    /// Encrypted link to paired iPads. Always advertised while the helper runs.
    public static let pairedType = "_halo._tcp"
    /// Pairing. Advertised only while the person has the pairing window open.
    public static let pairingType = "_halo-pair._tcp"

    /// TXT key carrying the Mac's `DeviceIdentity.id`, so an iPad finds *its* Mac.
    static let identityKey = "id"

    static func advertisement(type: String, for identity: DeviceIdentity) -> NWListener.Service {
        NWListener.Service(name: identity.name, type: type, txtRecord: NWTXTRecord([identityKey: identity.id.uuidString]))
    }
}
