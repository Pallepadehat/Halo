import CryptoKit
import Foundation
import Synchronization
import Testing
@testable import HaloTransport

@Suite struct PairingSessionTests {
    let pad = DeviceIdentity(id: UUID(), name: "Patrick's iPad")
    let mac = DeviceIdentity(id: UUID(), name: "Patrick's MacBook Pro")

    /// Records the code each side was shown, and answers with `accept`.
    final class Person: Sendable {
        let accept: Bool
        private let shown = Mutex<PairingProposal?>(nil)
        init(accepts accept: Bool = true) { self.accept = accept }

        var proposal: PairingProposal? { shown.withLock { $0 } }

        var confirm: PairingSession.Confirmation {
            { [self] proposal in
                shown.withLock { $0 = proposal }
                return accept
            }
        }
    }

    @Test func bothSidesSeeTheSameCodeAndAgreeOnASecret() async throws {
        let (padChannel, macChannel) = InMemoryChannel.pair()
        let padPerson = Person(), macPerson = Person()

        async let macResult = PairingSession.respond(over: macChannel, as: mac, confirm: macPerson.confirm)
        let padResult = try await PairingSession.initiate(over: padChannel, as: pad, confirm: padPerson.confirm)
        let macPairing = try await macResult

        #expect(padResult.identity == mac)
        #expect(macPairing.identity == pad)
        #expect(padResult.secret == macPairing.secret)

        let code = try #require(padPerson.proposal?.verificationCode)
        #expect(code.count == 6 && code.allSatisfy(\.isNumber))
        #expect(macPerson.proposal?.verificationCode == code)
        #expect(padPerson.proposal?.peer == mac)
        #expect(macPerson.proposal?.peer == pad)
    }

    @Test func declineOnEitherSideStopsPairing() async throws {
        let (padChannel, macChannel) = InMemoryChannel.pair()

        let macSide = Task { [mac] in
            try await PairingSession.respond(over: macChannel, as: mac, confirm: Person(accepts: false).confirm)
        }
        await #expect(throws: PairingError.declinedByPeer) {
            try await PairingSession.initiate(over: padChannel, as: pad, confirm: Person().confirm)
        }
        await #expect(throws: PairingError.declinedLocally) { try await macSide.value }
    }

    @Test func aManInTheMiddleCannotMakeTheCodesMatch() async throws {
        // The attacker pairs with each side separately, relaying nothing honest.
        let (padChannel, attackerToPad) = InMemoryChannel.pair()
        let (attackerToMac, macChannel) = InMemoryChannel.pair()
        let attacker = DeviceIdentity(id: UUID(), name: mac.name)
        let padPerson = Person(), macPerson = Person()

        async let fakeMac = PairingSession.respond(over: attackerToPad, as: attacker, confirm: { _ in true })
        async let fakePad = PairingSession.initiate(over: attackerToMac, as: attacker, confirm: { _ in true })
        async let realMac = PairingSession.respond(over: macChannel, as: mac, confirm: macPerson.confirm)
        _ = try await PairingSession.initiate(over: padChannel, as: pad, confirm: padPerson.confirm)
        _ = try await (fakeMac, fakePad, realMac)

        // Each person would now see a different code and decline (with odds of 1 in a million).
        #expect(padPerson.proposal?.verificationCode != macPerson.proposal?.verificationCode)
    }

    @Test func tamperedNonceIsDetected() {
        let pad = Data(repeating: 1, count: 32), mac = Data(repeating: 2, count: 32)
        let nonce = PairingCryptography.makeNonce()
        let commitment = PairingCryptography.commitment(to: nonce, initiatorKey: pad, responderKey: mac)

        #expect(PairingCryptography.isValid(commitment: commitment, to: nonce, initiatorKey: pad, responderKey: mac))
        #expect(!PairingCryptography.isValid(commitment: commitment, to: PairingCryptography.makeNonce(), initiatorKey: pad, responderKey: mac))
    }

    @Test func codesAreAlwaysSixDigits() {
        for _ in 0..<200 {
            let code = PairingCryptography.verificationCode(
                initiatorKey: PairingCryptography.makeNonce(), responderKey: PairingCryptography.makeNonce(),
                initiatorNonce: PairingCryptography.makeNonce(), responderNonce: PairingCryptography.makeNonce()
            )
            #expect(code.count == 6)
        }
    }
}
