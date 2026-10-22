import Network

private let noAuth: DNSServiceErrorType = -65555       // kDNSServiceErr_NoAuth (macOS)
private let policyDenied: DNSServiceErrorType = -65570 // kDNSServiceErr_PolicyDenied (iOS)

public extension Error {
    /// The system refused local networking because the person hasn't allowed it under
    /// Privacy & Security › Local Network. Retrying won't help until they change the setting.
    var isLocalNetworkDenied: Bool {
        guard case .dns(let code) = self as? NWError else { return false }
        return code == noAuth || code == policyDenied
    }
}
