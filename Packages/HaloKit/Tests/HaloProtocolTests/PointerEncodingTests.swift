import Foundation
import Testing
@testable import HaloProtocol

@Suite struct PointerEncodingTests {
    @Test func pointerEventsRoundTrip() throws {
        let events: [PointerEvent] = [
            .move(dx: 3.5, dy: -1, interval: 0.008),
            .button(.left, isPressed: true),
            .click(.right),
            .scroll(dx: 0, dy: 12, phase: .changed),
            .zoom(.in),
            .swipe(.left),
        ]
        for event in events {
            let data = try MessageCoder.encode(PadMessage.pointer(event))
            #expect(try MessageCoder.decode(PadMessage.self, from: data) == .pointer(event))
        }
    }

    /// JSON is kept for pointer events because it costs a few microseconds against a 20 ms
    /// budget dominated by Wi-Fi. This guards that assumption: if it fails, go binary.
    @Test func encodingAMoveFitsTheLatencyBudget() throws {
        let message = PadMessage.pointer(.move(dx: 3.25, dy: -1.5, interval: 0.0083))
        let iterations = 2_000
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for _ in 0..<iterations {
                _ = try MessageCoder.decode(PadMessage.self, from: MessageCoder.encode(message))
            }
        }
        #expect(elapsed / iterations < .microseconds(200))
        #expect(try MessageCoder.encode(message).count < 100)
    }
}
