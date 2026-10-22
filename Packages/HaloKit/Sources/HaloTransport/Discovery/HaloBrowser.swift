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
    public enum Update: Sendable, Equatable {
        case found([DiscoveredMac])
        /// Local Network access is off. Browsing resumes by itself once it's allowed.
        case localNetworkDenied
    }

    public let updates: AsyncStream<Update>

    private let browser: NWBrowser
    private let continuation: AsyncStream<Update>.Continuation
    private let queue = DispatchQueue(label: "app.halo.browser")

    public init(type: String) {
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: HaloNetworkParameters.discovery())
        (updates, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public func start() {
        browser.browseResultsChangedHandler = { [continuation] results, _ in
            continuation.yield(.found(results.compactMap(DiscoveredMac.init)))
        }
        browser.stateUpdateHandler = { [continuation] state in
            switch state {
            case .waiting(let error) where error.isLocalNetworkDenied:
                continuation.yield(.localNetworkDenied)
            case .failed(let error):
                if error.isLocalNetworkDenied { continuation.yield(.localNetworkDenied) }
                continuation.finish()
            case .cancelled:
                continuation.finish()
            default:
                break
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
