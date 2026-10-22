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
