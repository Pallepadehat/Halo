import CryptoKit
import Foundation
import Testing
@testable import HaloTransport

/// Skipped on CI: hosted runners' keychains can't be relied on to accept new items.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
struct KeychainPairedDeviceStoreTests {
    let store = KeychainPairedDeviceStore(service: "app.halo.tests.\(UUID().uuidString)")

    @Test func savesLoadsAndRemovesPairings() throws {
        let device = PairedDevice(identity: DeviceIdentity(id: UUID(), name: "iPad"), secret: SymmetricKey(size: .bits256))
        defer { try? store.remove(device.id) }

        try store.save(device)
        try store.save(device) // Saving again updates in place.
        let loaded = try store.load()
        #expect(loaded.map(\.identity) == [device.identity])
        #expect(loaded.first?.secret == device.secret)

        try store.remove(device.id)
        #expect(try store.load().isEmpty)
    }
}
