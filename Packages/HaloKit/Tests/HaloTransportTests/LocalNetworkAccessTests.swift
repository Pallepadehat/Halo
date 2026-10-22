import Network
import Testing
@testable import HaloTransport

@Suite struct LocalNetworkAccessTests {
    @Test func recognisesBonjourPermissionDenials() {
        #expect(NWError.dns(-65555).isLocalNetworkDenied)
        #expect(NWError.dns(-65570).isLocalNetworkDenied)
    }

    @Test func otherFailuresAreNotPermissionProblems() {
        #expect(!NWError.dns(-65537).isLocalNetworkDenied)
        #expect(!NWError.posix(.ECONNREFUSED).isLocalNetworkDenied)
        #expect(!ChannelError.closed.isLocalNetworkDenied)
    }
}
