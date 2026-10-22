import Foundation
import Security

/// Persists pairings. Secrets never leave the Keychain except to key a connection.
public protocol PairedDeviceStore: Sendable {
    func load() throws -> [PairedDevice]
    func save(_ device: PairedDevice) throws
    func remove(_ id: PairedDevice.ID) throws
}

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
}

/// One generic-password item per paired device, available only on this device.
public struct KeychainPairedDeviceStore: PairedDeviceStore {
    private let service: String

    public init(service: String = "app.halo.paired-devices") {
        self.service = service
    }

    public func load() throws -> [PairedDevice] {
        // The macOS file keychain can't return data for many items at once, so list the
        // accounts first and read each one.
        try accounts()
            .map { try JSONDecoder().decode(PairedDevice.self, from: data(for: $0)) }
            .sorted { $0.pairedAt < $1.pairedAt }
    }

    public func save(_ device: PairedDevice) throws {
        let data = try JSONEncoder().encode(device)
        var query = baseQuery(account: device.id)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard status == errSecItemNotFound else {
            guard status == errSecSuccess else { throw KeychainError(status: status) }
            return
        }

        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(query as CFDictionary, nil)
        guard added == errSecSuccess else { throw KeychainError(status: added) }
    }

    public func remove(_ id: PairedDevice.ID) throws {
        let status = SecItemDelete(baseQuery(account: id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func accounts() throws -> [UUID] {
        var query = baseQuery()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true

        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            let items = result as? [[CFString: Any]] ?? []
            return items.compactMap { ($0[kSecAttrAccount] as? String).flatMap(UUID.init(uuidString:)) }
        case errSecItemNotFound:
            return []
        case let status:
            throw KeychainError(status: status)
        }
    }

    private func data(for account: UUID) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return data
    }

    private func baseQuery(account: UUID? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
        if let account { query[kSecAttrAccount] = account.uuidString }
        return query
    }
}
