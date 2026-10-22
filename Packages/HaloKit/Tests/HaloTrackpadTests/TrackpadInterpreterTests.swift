import Testing
import HaloProtocol
@testable import HaloTrackpad

/// Drives the interpreter like UIKit does: the full touch set after every change.
/// Time advances in sixteenths of a second, which binary floating point represents exactly.
private struct Hand {
    static let step = 1.0 / 16

    var interpreter = TrackpadInterpreter()
    var time = 0.0
    var events: [PointerEvent] = []

    mutating func touch(_ points: [(Double, Double)], after seconds: Double = Hand.step) {
        time += seconds
        let touches = points.enumerated().map { TouchPoint(id: $0.offset, x: $0.element.0, y: $0.element.1) }
        events += interpreter.update(touches, at: time)
    }

    mutating func lift(after seconds: Double = Hand.step) {
        touch([], after: seconds)
    }

    mutating func wait(_ seconds: Double) {
        time += seconds
        events += interpreter.holdElapsed(at: time)
    }
}

@Suite struct TrackpadInterpreterTests {
    @Test func oneFingerMovesThePointerOncePastTheSlop() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.touch([(102, 100)])            // within slop: still a possible tap
        hand.touch([(110, 104)])
        hand.touch([(120, 104)], after: Hand.step / 2)
        hand.lift()

        #expect(hand.events == [
            .move(dx: 8, dy: 4, interval: Hand.step),
            .move(dx: 10, dy: 0, interval: Hand.step / 2),
        ])
    }

    @Test func quickTapClicks() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.touch([(101, 101)])
        hand.lift()
        #expect(hand.events == [.click(.left)])
    }

    @Test func slowLiftIsNotATap() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.lift(after: 0.3125)
        #expect(hand.events.isEmpty)
    }

    @Test func twoFingerTapRightClicksEvenIfFingersLandApart() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.touch([(100, 100), (160, 100)])
        hand.touch([(160, 100)])
        hand.lift()
        #expect(hand.events == [.click(.right)])
    }

    @Test func holdThenMoveDrags() {
        var hand = Hand()
        hand.touch([(100, 100)])
        #expect(hand.interpreter.isAwaitingHold)
        hand.wait(0.5)
        hand.touch([(130, 100)])
        hand.lift()

        #expect(hand.events == [
            .button(.left, isPressed: true),
            .move(dx: 30, dy: 0, interval: 0.5 + Hand.step),
            .button(.left, isPressed: false),
        ])
    }

    @Test func holdIsCancelledByMovement() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.touch([(140, 100)])
        #expect(!hand.interpreter.isAwaitingHold)
        hand.wait(1)
        #expect(!hand.events.contains(.button(.left, isPressed: true)))
    }

    @Test func twoFingersScrollWithPhases() {
        var hand = Hand()
        hand.touch([(100, 100), (150, 100)])
        hand.touch([(100, 110), (150, 110)])
        hand.touch([(100, 125), (150, 125)])
        hand.lift()

        #expect(hand.events == [
            .scroll(dx: 0, dy: 10, phase: .began),
            .scroll(dx: 0, dy: 15, phase: .changed),
            .scroll(dx: 0, dy: 0, phase: .ended),
        ])
    }

    @Test func pinchingOutZoomsIn() {
        var hand = Hand()
        hand.touch([(100, 100), (200, 100)])
        hand.touch([(80, 100), (220, 100)])   // spread 50 → 70: one step
        hand.touch([(60, 100), (240, 100)])   // 70 → 90: one more
        hand.lift()

        #expect(hand.events == [.zoom(.in), .zoom(.in)])
    }

    @Test func scrollingNeverTurnsIntoAZoom() {
        var hand = Hand()
        hand.touch([(100, 100), (200, 100)])
        hand.touch([(100, 120), (200, 120)])
        hand.touch([(60, 140), (240, 140)])
        #expect(!hand.events.contains(.zoom(.in)))
    }

    @Test(arguments: [
        ((-80.0, 0.0), SwipeDirection.left),
        ((80.0, 0.0), SwipeDirection.right),
        ((0.0, -80.0), SwipeDirection.up),
        ((0.0, 80.0), SwipeDirection.down),
    ])
    func threeFingersSwipeOncePerGesture(translation: (Double, Double), direction: SwipeDirection) {
        var hand = Hand()
        let start = [(100.0, 100.0), (140.0, 100.0), (180.0, 100.0)]
        hand.touch(start)
        for step in 1...4 {
            let offset = (translation.0 * Double(step) / 2, translation.1 * Double(step) / 2)
            hand.touch(start.map { ($0.0 + offset.0, $0.1 + offset.1) })
        }
        hand.lift()
        #expect(hand.events == [.swipe(direction)])
    }

    @Test func addingAFingerDoesNotJumpThePointer() {
        var hand = Hand()
        hand.touch([(100, 100)])
        hand.touch([(120, 100)])
        hand.touch([(120, 100), (300, 300)])   // centroid jumps by ~127pt
        hand.touch([(120, 100)])
        hand.touch([(125, 100)])

        let moves = hand.events.compactMap { event -> Double? in
            if case .move(let dx, _, _) = event { dx } else { nil }
        }
        #expect(moves == [20, 5])
    }
}

@Suite struct CustomGestureTests {
    @Test(arguments: [(3, TrackpadGesture.threeFingerTap), (4, TrackpadGesture.fourFingerTap)])
    func multiFingerTapsBecomeCustomGestures(fingers: Int, gesture: TrackpadGesture) {
        var interpreter = TrackpadInterpreter()
        let touches = (0..<fingers).map { TouchPoint(id: $0, x: 100 + Double($0) * 40, y: 100) }
        _ = interpreter.update(Array(touches.prefix(1)), at: 0)
        _ = interpreter.update(touches, at: 0.02)
        let events = interpreter.update([], at: 0.1)

        #expect(events.isEmpty, "A custom gesture never clicks")
        #expect(interpreter.takeGesture() == gesture)
        #expect(interpreter.takeGesture() == nil, "Taken once")
    }

    @Test func aThreeFingerSwipeIsNotATap() {
        var interpreter = TrackpadInterpreter()
        let start = [(100.0, 100.0), (140.0, 100.0), (180.0, 100.0)]
        _ = interpreter.update(start.enumerated().map { TouchPoint(id: $0.offset, x: $0.element.0, y: $0.element.1) }, at: 0)
        _ = interpreter.update(start.enumerated().map { TouchPoint(id: $0.offset, x: $0.element.0 + 90, y: $0.element.1) }, at: 0.05)
        _ = interpreter.update([], at: 0.1)
        #expect(interpreter.takeGesture() == nil)
    }
}
