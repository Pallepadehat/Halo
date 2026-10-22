import Foundation

/// Who a device is, as shown to the person pairing it.
public struct DeviceIdentity: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

public extension DeviceIdentity {
    /// This device's identity: an ID minted on first launch and kept in `defaults`.
    static func local(named name: String, defaults: UserDefaults = .standard) -> DeviceIdentity {
        let key = "app.halo.device-id"
        if let stored = defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) {
            return DeviceIdentity(id: stored, name: name)
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return DeviceIdentity(id: id, name: name)
    }
}
