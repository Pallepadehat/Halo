import Testing
import HaloProtocol
@testable import HaloInput

@Suite struct PointerAccelerationTests {
    let curve = PointerAcceleration()

    @Test func slowMotionStaysPrecise() {
        // 1 point over 16 ms: barely moving.
        #expect(curve.gain(dx: 1, dy: 0, interval: 0.016) < 1.2)
    }

    @Test func fastFlicksGoFurtherButAreCapped() {
        let fast = curve.gain(dx: 30, dy: 0, interval: 0.008)
        #expect(fast == curve.maximumGain)
        #expect(curve.gain(dx: 4, dy: 0, interval: 0.008) > curve.gain(dx: 1, dy: 0, interval: 0.008))
    }

    @Test func aPauseDoesNotReadAsSlowMotion() {
        // A long gap since the last move shouldn't make the next one ultra-precise.
        #expect(curve.gain(dx: 10, dy: 0, interval: 2) == curve.gain(dx: 10, dy: 0, interval: curve.maximumInterval))
    }
}

@Suite struct ClickCounterTests {
    @Test func countsRepeatedClicksInPlace() {
        var counter = ClickCounter(interval: 0.5)
        #expect(counter.register(.left, at: 0, x: 10, y: 10) == 1)
        #expect(counter.register(.left, at: 0.3, x: 11, y: 10) == 2)
        #expect(counter.register(.left, at: 0.6, x: 11, y: 11) == 3)
    }

    @Test func resetsOnTimeoutDistanceOrButton() {
        var counter = ClickCounter(interval: 0.5)
        _ = counter.register(.left, at: 0, x: 10, y: 10)
        #expect(counter.register(.left, at: 0.9, x: 10, y: 10) == 1)
        #expect(counter.register(.left, at: 1.0, x: 40, y: 10) == 1)
        #expect(counter.register(.right, at: 1.1, x: 40, y: 10) == 1)
    }
}

@Suite struct ScrollAccumulatorTests {
    @Test func carriesFractionsSoSlowScrollsStillMove() {
        var scroll = ScrollAccumulator(isNatural: true)
        let deltas = (0..<4).map { _ in scroll.wheelDeltas(dx: 0, dy: 0.4).vertical }
        #expect(deltas == [0, 0, 1, 0])
    }

    @Test func respectsTheScrollDirectionPreference() {
        var natural = ScrollAccumulator(isNatural: true)
        var classic = ScrollAccumulator(isNatural: false)
        #expect(natural.wheelDeltas(dx: 3, dy: 10) == (3, 10))
        #expect(classic.wheelDeltas(dx: 3, dy: 10) == (-3, -10))
    }
}
