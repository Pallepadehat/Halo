import Foundation
import Network

/// A Mac advertising Halo on the local network.
public struct DiscoveredMac: Sendable, Hashable, Identifiable {
    public let identity: DeviceIdentity
    public let endpoint: NWEndpoint

    public var id: UUID { identity.id }
}

/// Browses for Halo Macs, publishing the full set every time it changes.
public final class HaloBrowser: Sendable {
    public let results: AsyncStream<[DiscoveredMac]>

    private let browser: NWBrowser
    private let continuation: AsyncStream<[DiscoveredMac]>.Continuation
    private let queue = DispatchQueue(label: "app.halo.browser")

    public init(type: String) {
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: HaloNetworkParameters.discovery())
        (results, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public func start() {
        browser.browseResultsChangedHandler = { [continuation] results, _ in
            continuation.yield(results.compactMap(DiscoveredMac.init))
        }
        browser.stateUpdateHandler = { [continuation] state in
            switch state {
            case .failed, .cancelled: continuation.finish()
            default: break
            }
        }
        browser.start(queue: queue)
    }

    public func cancel() {
        browser.cancel()
    }
}

private extension DiscoveredMac {
    init?(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint,
              case .bonjour(let record) = result.metadata,
              let id = record[HaloService.identityKey].flatMap(UUID.init(uuidString:))
        else { return nil }
        self.init(identity: DeviceIdentity(id: id, name: name), endpoint: result.endpoint)
    }
}
